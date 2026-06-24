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
HC_NAMESPACE="hcp-ai"
HC_NAME="ai"

echo "=== HCP OAuth / user setup ==="
echo "  HostedCluster:   ${HC_NAMESPACE}/${HC_NAME}"
echo "  Guest cluster:   $(./oc whoami --show-server)"
echo "  Mgmt cluster:    $(oc whoami --show-server)"
echo ""

# --- Step 1: Create htpasswd secret on the management cluster ---
# HyperShift syncs secrets referenced by the HostedCluster CR from the HC
# namespace down to openshift-config on the guest cluster.
echo "[1/3] Creating htpasswd secret in ${HC_NAMESPACE} on management cluster..."

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
echo "[2/3] Patching HostedCluster ${HC_NAMESPACE}/${HC_NAME} with OAuth config..."

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

echo "    Waiting for OAuth config to propagate to guest cluster..."
for i in $(seq 1 30); do
  idp_count=$(./oc get oauth cluster -o jsonpath='{.spec.identityProviders}' 2>/dev/null | grep -c htpasswd || true)
  if [[ "${idp_count}" -ge 1 ]]; then
    echo "    OAuth htpasswd IDP is active on guest cluster."
    break
  fi
  if [[ "${i}" -eq 30 ]]; then
    echo "    WARNING: OAuth not propagated after 60s."
    echo "    Debug with: oc get hostedcluster ${HC_NAME} -n ${HC_NAMESPACE} -o jsonpath='{.spec.configuration.oauth}'"
    echo "                ./oc get oauth cluster -o yaml"
  fi
  sleep 2
done

# --- Step 3: Verification ---
echo ""
echo "=== [3/3] Verification ==="
echo ""
echo "--- HostedCluster OAuth config (management cluster) ---"
oc get hostedcluster ${HC_NAME} -n ${HC_NAMESPACE} \
  -o jsonpath='{.spec.configuration.oauth}' | python3 -m json.tool 2>/dev/null || \
  oc get hostedcluster ${HC_NAME} -n ${HC_NAMESPACE} \
  -o jsonpath='{.spec.configuration.oauth}'
echo ""
echo ""
echo "--- OAuth resource on guest cluster ---"
./oc get oauth cluster -o yaml | grep -A 20 'identityProviders'
echo ""
echo "Done."
echo ""
echo "NOTE: The GitHub IDP from your gitops repo is not included here."
echo "      To add it, create the 'github-oauth-sandbox' secret in ${HC_NAMESPACE}"
echo "      on the management cluster, then add the GitHub IDP to the"
echo "      HostedCluster patch above."
