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
#   ./oc  = guest/hosted cluster
#   oc    = management cluster

echo "=== HCP Unpause: ${CLUSTER_NAME} ==="
echo "  Namespace:          ${NAMESPACE}"
echo "  HCP Namespace:      ${HCP_NAMESPACE}"
echo "  Region:             ${REGION}"
echo "  Default Node Pool:  ${DEFAULT_NODE_POOL}"
echo "  Default Node Count: ${DEFAULT_NODE_COUNT}"
echo ""

echo "make sure you are logged into the management cluster"
oc whoami --show-server
echo "type any key or ctrl c to exit"
read a


# --- Step 1: Re-enable reconciliation ---
echo "--- Step 1: Re-enabling reconciliation ---"
oc patch hostedcluster "${SHORT_NAME}" -n "${NAMESPACE}" \
  --type merge -p '{"spec":{"pausedUntil": null}}'

PAUSED=$(oc get hostedcluster "${SHORT_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.pausedUntil}')
if [[ -z "$PAUSED" || "$PAUSED" == "null" ]]; then
  echo "  Reconciliation re-enabled successfully."
else
  echo "  ERROR: pausedUntil is '${PAUSED}', expected empty/null."
  exit 1
fi

echo "  Waiting for control plane operator to reconcile deployments..."

MAX_WAIT=300
ELAPSED=0
INTERVAL=10

while true; do
  READY=$(oc get deploy kube-apiserver -n "${HCP_NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)
  READY="${READY:-0}"
  DESIRED=$(oc get deploy kube-apiserver -n "${HCP_NAMESPACE}" -o jsonpath='{.spec.replicas}' 2>/dev/null || true)
  DESIRED="${DESIRED:-0}"

  if [[ "$READY" -gt 0 && "$READY" == "$DESIRED" ]]; then
    echo "  kube-apiserver is ready (${READY}/${DESIRED} replicas)."
    break
  fi

  echo "  kube-apiserver: ${READY:-0}/${DESIRED:-?} ready (waited ${ELAPSED}s)..."

  if [[ $ELAPSED -ge $MAX_WAIT ]]; then
    echo "  WARNING: Timed out waiting for kube-apiserver after ${MAX_WAIT}s."
    echo "  Proceeding with nodepool scale-up anyway..."
    break
  fi

  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done

# --- Step 2: Scale up default nodepool ---
echo ""
echo "--- Step 2: Scaling up nodepool ${DEFAULT_NODE_POOL} to ${DEFAULT_NODE_COUNT} ---"
oc scale nodepool "${DEFAULT_NODE_POOL}" -n "${NAMESPACE}" --replicas="${DEFAULT_NODE_COUNT}"

REPLICAS=$(oc get nodepool "${DEFAULT_NODE_POOL}" -n "${NAMESPACE}" -o jsonpath='{.spec.replicas}')
echo "  Nodepool ${DEFAULT_NODE_POOL} set to ${REPLICAS} replicas."
echo "  Nodes will take several minutes to provision and join the cluster."

echo ""
echo "=== HCP Unpause complete for ${SHORT_NAME} ==="
echo "  Monitor progress with:"
echo "    oc get nodepool -n ${NAMESPACE}"
echo "    oc get nodes --kubeconfig <guest-kubeconfig>"
