#!/bin/sh
source ./env.sh
source ~/.secrets/akeyless-ocp-hub.txt


KUBECONFIG=$KUBECONFIG oc create -f - <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: external-secrets
  labels:
    argocd.argoproj.io/managed-by: openshift-gitops
EOF

sleep 1
### THE API AKEYLESS CREDS
## THIS SECRET WILL BE REFERENCED BY THE clustersecretstore to be created later
KUBECONFIG=$KUBECONFIG oc create -f - <<EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: akeyless-secret-creds
  namespace: external-secrets
type: Opaque
stringData:
  accessId: $AKEYLESS_ACCESS_ID
  accessType:  api_key
  accessTypeParam:  $AKEYLESS_ACCESS_KEY
EOF

echo "done creating 1 secret for the ESO to access akeyless"
