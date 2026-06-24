#!/usr/bin/env bash
set -euo pipefail

# Configure OAuth identity providers on a Hosted Control Plane cluster.
#
# On HCP, the OAuth resource on the guest cluster is protected by a
# ValidatingAdmissionPolicy — only the HyperShift operator can modify it.
# Instead, we configure OAuth through the HostedCluster CR on the management
# cluster, and create the backing secrets in the HostedCluster namespace.
#
# Convention:
#   ./oc  = guest/hosted cluster (ai)
#   oc    = management cluster

source ./env.sh
source ~/.secrets/$MYDIR/route53

CLUSTER_NAME="${CLUSTER_NAME:?CLUSTER_NAME is not set (from env.sh)}"
HC_NAMESPACE="hcp-$SHORT_NAME"
HC_NAME="$SHORT_NAME"

echo "=== HCP OAuth / user setup ==="
echo "  HostedCluster:   ${HC_NAMESPACE}/${HC_NAME}"
echo "  Guest cluster:   $(./oc whoami --show-server)"
echo "  Mgmt cluster:    $(oc whoami --show-server)"
echo ""
echo "CHECK ABOVE and press a key to continue, ctrl-c to cancel"
read a


# --- Step 1: Create htpasswd secret on the management cluster ---
# HyperShift syncs secrets referenced by the HostedCluster CR from the HC
# namespace down to openshift-config on the guest cluster.
echo "[1/4] Creating htpasswd secret in ${HC_NAMESPACE} on management cluster..."

HTPASSWD_DATA="YWxpY2U6JGFwcjEkakV3MG82MDYkZnRyaGtVMUl1Y1dkRjRXM2tVdVhPLgpib2I6JGFwcjEkQWRiQTRzcjYkVWNCZWdBL3pMS3V3dUJLWVhlNy82MApjaGFybGllOiRhcHIxJDVSYW5GcVdXJE5XZFlpRlgyNjAvbXUuNnNEdEdHTjEKemVhZG1pbjokYXByMSRLcWVqMXEzZiRuMnpsUndaQlVvS0t1alZUcHRRWnEwCmNocmlzOiRhcHIxJGxkVXhFSlFmJERtLkcxSWRTenk3Vy9EYWQudzJCUi8KY2hyaXMtYWRtaW46JGFwcjEkMEdxSC9oZDIkdXhxdlpmOUY5ZHJCWk9kcktGVktGLwo="

oc apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: htpass-my-secret
  namespace: ${HC_NAMESPACE}
type: Opaque
data:
  htpasswd: ${HTPASSWD_DATA}
EOF

# --- Step 2: Patch HostedCluster OAuth configuration ---
# This is the HCP equivalent of editing the OAuth/cluster resource directly.
# HyperShift will reconcile this into the guest cluster's OAuth config via
# the privileged system:hosted-cluster-config service account.
echo "[2/4] Patching HostedCluster ${HC_NAMESPACE}/${HC_NAME} with OAuth config..."

oc patch hostedcluster ${HC_NAME} -n ${HC_NAMESPACE} \
  --type=merge \
  -p '{
  "spec": {
    "configuration": {
      "oauth": {
        "identityProviders": [
          {
            "name": "htpasswd",
            "mappingMethod": "claim",
            "type": "HTPasswd",
            "htpasswd": {
              "fileData": {
                "name": "htpass-my-secret"
              }
            }
          }
        ]
      }
    }
  }
}'

echo "    Waiting for oauth-openshift pods to roll out on management cluster..."
# On HCP, auth pods run in the control plane namespace on the mgmt cluster.
# The guest cluster's OAuth/cluster resource may stay spec:{} — that's normal.
HC_CP_NAMESPACE="${HC_NAMESPACE}-${HC_NAME}"
for i in $(seq 1 30); do
  ready=$(oc get deployment oauth-openshift -n "${HC_CP_NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  if [[ "${ready}" -ge 1 ]]; then
    echo "    oauth-openshift is ready (${ready} replicas) in ${HC_CP_NAMESPACE}."
    break
  fi
  if [[ "${i}" -eq 30 ]]; then
    echo "    WARNING: oauth-openshift not ready after 60s."
    echo "    Debug with: oc get deployment oauth-openshift -n ${HC_CP_NAMESPACE}"
  fi
  sleep 2
done

# --- Step 3: Create ClusterRoleBinding on the guest cluster ---
# ArgoCD's in-cluster-users app manages this CRB, but its sync is blocked by
# the OAuth admission policy. Apply it directly so htpasswd users get
# cluster-admin immediately.
echo "[3/4] Creating ClusterRoleBinding cluster-admin-0 on guest cluster..."
./oc apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-admin-0
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: zeadmin
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: chris-admin
EOF

# --- Step 4: Verification ---
echo ""
echo "=== [4/4] Verification ==="
echo ""
echo "--- HostedCluster OAuth config (management cluster) ---"
oc get hostedcluster ${HC_NAME} -n ${HC_NAMESPACE} \
  -o jsonpath='{.spec.configuration.oauth}' | python3 -m json.tool 2>/dev/null || \
  oc get hostedcluster ${HC_NAME} -n ${HC_NAMESPACE} \
  -o jsonpath='{.spec.configuration.oauth}'
echo ""
echo ""
echo "--- ClusterRoleBinding on guest cluster ---"
./oc get clusterrolebinding cluster-admin-0 -o wide
echo ""
echo "Done."
echo ""
echo "NOTE: The GitHub IDP from your gitops repo is not included here."
echo "      To add it, create the 'github-oauth-sandbox' secret in ${HC_NAMESPACE}"
echo "      on the management cluster, then add the GitHub IDP to the"
echo "      HostedCluster patch above."
