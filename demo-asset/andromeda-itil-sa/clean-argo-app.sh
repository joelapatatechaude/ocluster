#!/bin/sh
set -a
source ./env.sh
set +a

ARGO_SERVER=$(KUBECONFIG=$KUBECONFIG oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')
ARGO_PASSWORD=$(KUBECONFIG=$KUBECONFIG oc get secret openshift-gitops-cluster -n openshift-gitops -o json | jq -r '.data."admin.password"' | base64 -d)

function list_app {
    echo $ARGO_SERVER
    echo $ARGO_PASSWORD
    argocd login --username admin --password $ARGO_PASSWORD $ARGO_SERVER --config=$ARGO_CONFIG --insecure
    argocd app list -o name  --insecure --server $ARGO_SERVER --config=$ARGO_CONFIG | grep hello-quarkus > argo-to-delete

}

list_app

echo "going to delete the following argo app"
cat argo-to-delete

echo ""
echo "press a key if ok"
read a

for i in `cat argo-to-delete`; do
    echo "going to delete $i in 0 sec"
    sleep 0
    argocd app delete $i --cascade --server $ARGO_SERVER --config=$ARGO_CONFIG -y
done
