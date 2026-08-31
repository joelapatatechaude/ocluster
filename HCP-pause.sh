#!/usr/bin/env bash
set -euo pipefail

source ./env.sh
source ~/.secrets/$MYDIR/route53
source ~/.secrets/$MYDIR/aws-creds

CLUSTER_NAME="${CLUSTER_NAME:?CLUSTER_NAME not set — source env.sh first}"
NAMESPACE="hcp-${SHORT_NAME:?SHORT_NAME not set — source env.sh first}"
HCP_NAMESPACE="${NAMESPACE}-${SHORT_NAME}"
REGION="${HCP_REGION:?HCP_REGION not set — source env.sh first}"
DEFAULT_NODE_POOL="${DEFAULT_NODE_POOL:?DEFAULT_NODE_POOL not set — source env.sh first}"
DEFAULT_NODE_COUNT="${DEFAULT_NODE_COUNT:?DEFAULT_NODE_COUNT not set — source env.sh first}"

# Convention:
#   ./oc  = guest/hosted cluster (ai)
#   oc    = management cluster

GUEST_OC="./oc"

DEPLOYMENTS_TO_SCALE=(
  olm-operator
  kube-apiserver
  control-plane-operator
  hosted-cluster-config-operator
  ingress-operator
)

# Drain grace period: after this many seconds, force-terminate stuck instances
DRAIN_GRACE=300
MAX_WAIT=600
INTERVAL=15


echo "=== HCP Pause:    ${CLUSTER_NAME} ==="
echo "  ShortName:      ${SHORT_NAME} ==="
echo "  Namespace:      ${NAMESPACE}"
echo "  HCP Namespace:  ${HCP_NAMESPACE}"
echo "  Region:         ${REGION}"
echo "  Node Pool:      ${DEFAULT_NODE_POOL}"
echo "  Node count:     ${DEFAULT_NODE_COUNT}"
echo ""

echo "make sure you are logged into the management cluster"
oc whoami --show-server
echo "type any key or ctrl c to exit"
read a


#echo "hard coded exit"
#exit

# --- Step 1: Remove operator-managed PDBs on guest cluster (prevents drain deadlocks) ---
echo "--- Step 1: Removing operator-managed PodDisruptionBudgets on guest cluster ---"
echo "  (Only deleting PDBs with ownerReferences — operators will recreate them on unpause)"

PDBS_JSON=$($GUEST_OC get pdb -A -o json 2>/dev/null || echo '{"items":[]}')
PDBS_TO_DELETE=$(echo "$PDBS_JSON" | python3 -c '
import json, sys
data = json.load(sys.stdin)
for item in data.get("items", []):
    owners = item.get("metadata", {}).get("ownerReferences", [])
    if owners:
        ns = item["metadata"]["namespace"]
        name = item["metadata"]["name"]
        owner = owners[0].get("kind", "unknown")
        print(f"{ns} {name} {owner}")
' 2>/dev/null || true)

if [[ -n "$PDBS_TO_DELETE" ]]; then
  while read -r PDB_NS PDB_NAME PDB_OWNER; do
    [[ -z "$PDB_NS" || -z "$PDB_NAME" ]] && continue
    echo "  Deleting PDB ${PDB_NS}/${PDB_NAME} (managed by ${PDB_OWNER})"
    $GUEST_OC delete pdb "${PDB_NAME}" -n "${PDB_NS}" --ignore-not-found 2>/dev/null || true
  done <<< "$PDBS_TO_DELETE"
else
  echo "  No operator-managed PDBs found on guest cluster."
fi

# Warn about manually-created PDBs (no ownerReference) — leave them alone
MANUAL_PDBS=$(echo "$PDBS_JSON" | python3 -c '
import json, sys
data = json.load(sys.stdin)
for item in data.get("items", []):
    owners = item.get("metadata", {}).get("ownerReferences", [])
    if not owners:
        ns = item["metadata"]["namespace"]
        name = item["metadata"]["name"]
        print(f"{ns}/{name}")
' 2>/dev/null || true)

if [[ -n "$MANUAL_PDBS" ]]; then
  echo ""
  echo "  WARNING: The following PDBs have no ownerReference (manually created?) — NOT deleting:"
  while read -r PDB_REF; do
    echo "    ${PDB_REF}"
  done <<< "$MANUAL_PDBS"
  echo "  These may block the drain. Delete manually if needed."
fi

# --- Step 2: Scale all nodepools to zero ---
echo ""
echo "--- Step 2: Scaling all nodepools to zero ---"
NODEPOOLS=$(oc get nodepool -n "${NAMESPACE}" -o jsonpath='{range .items[?(@.spec.clusterName=="'"${SHORT_NAME}"'")]}{.metadata.name}{" "}{.spec.replicas}{"\n"}{end}')

if [[ -z "$NODEPOOLS" ]]; then
  echo "  No nodepools found for cluster ${CLUSTER_NAME}"
else
  while IFS=' ' read -r NP_NAME NP_REPLICAS; do
    [[ -z "$NP_NAME" ]] && continue
    if [[ "$NP_REPLICAS" == "0" ]]; then
      echo "  ${NP_NAME}: already at 0 replicas, skipping"
    else
      echo "  ${NP_NAME}: scaling from ${NP_REPLICAS} to 0"
      oc scale nodepool "${NP_NAME}" -n "${NAMESPACE}" --replicas=0
    fi
  done <<< "$NODEPOOLS"
fi

# --- Step 3: Wait for EC2 instances to terminate ---
echo ""
echo "--- Step 3: Waiting for EC2 instances to terminate ---"
INFRA_ID=$(oc get hostedcluster "${SHORT_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.infraID}')
echo "  Infra ID: ${INFRA_ID}"

ELAPSED=0
FORCE_ATTEMPTED=false

while true; do
  RUNNING=$(aws ec2 describe-instances \
    --region "${REGION}" \
    --filters "Name=tag:kubernetes.io/cluster/${INFRA_ID},Values=owned" \
              "Name=instance-state-name,Values=running,pending,stopping,shutting-down" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text 2>/dev/null || true)

  if [[ -z "$RUNNING" || "$RUNNING" == "None" ]]; then
    echo "  All EC2 instances terminated."
    break
  fi

  COUNT=$(echo "$RUNNING" | wc -w)
  echo "  ${COUNT} instance(s) still active (waited ${ELAPSED}s)..."

  # After DRAIN_GRACE, machines may be stuck — force-terminate via AWS
  if [[ $ELAPSED -ge $DRAIN_GRACE && "$FORCE_ATTEMPTED" == "false" ]]; then
    FORCE_ATTEMPTED=true
    echo ""
    echo "  *** Drain grace period exceeded (${DRAIN_GRACE}s). Checking for stuck machines... ***"

    STUCK=$(oc get machines -n "${HCP_NAMESPACE}" \
      -o jsonpath='{range .items[?(@.status.phase=="Deleting")]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)

    if [[ -n "$STUCK" ]]; then
      echo "  Found machines stuck in Deleting phase:"
      while read -r M_NAME; do
        [[ -z "$M_NAME" ]] && continue
        REASON=$(oc get machine "$M_NAME" -n "${HCP_NAMESPACE}" \
          -o jsonpath='{.status.conditions[?(@.type=="DrainingSucceeded")].message}' 2>/dev/null || echo "unknown")
        echo "    ${M_NAME}: ${REASON}"
      done <<< "$STUCK"
    fi

    echo "  Force-terminating ${COUNT} EC2 instance(s) via AWS API..."
    aws ec2 terminate-instances --region "${REGION}" --instance-ids $RUNNING 2>/dev/null || true
    echo "  Terminate request sent. Waiting for shutdown..."
  fi

  if [[ $ELAPSED -ge $MAX_WAIT ]]; then
    echo "  WARNING: Timed out after ${MAX_WAIT}s. ${COUNT} instances may still be shutting down."
    echo "  Proceeding with pause..."
    break
  fi

  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done

# --- Step 4: Pause reconciliation ---
echo ""
echo "--- Step 4: Pausing reconciliation ---"
oc patch hostedcluster "${SHORT_NAME}" -n "${NAMESPACE}" \
  --type merge -p '{"spec":{"pausedUntil":"true"}}'

PAUSED=$(oc get hostedcluster "${SHORT_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.pausedUntil}')
if [[ "$PAUSED" == "true" ]]; then
  echo "  Reconciliation paused successfully."
else
  echo "  ERROR: pausedUntil is '${PAUSED}', expected 'true'."
  exit 1
fi

echo "  Waiting 30 seconds for controllers to settle..."
sleep 30

# --- Step 5: Scale down control plane deployments ---
echo ""
echo "--- Step 5: Scaling down control plane deployments ---"
for DEPLOY in "${DEPLOYMENTS_TO_SCALE[@]}"; do
  if oc get deploy "${DEPLOY}" -n "${HCP_NAMESPACE}" &>/dev/null; then
    oc scale deploy "${DEPLOY}" -n "${HCP_NAMESPACE}" --replicas=0
    echo "  Scaled down: ${DEPLOY}"
  else
    echo "  Skipped (not found): ${DEPLOY}"
  fi
done

echo ""
echo "=== HCP Pause complete for ${CLUSTER_NAME} ==="
