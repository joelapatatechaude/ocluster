#!/bin/sh
source ./env.sh
source ~/.secrets/$MYDIR/route53
echo "Looking ONLY for *.yaml files"

function apply {
    for i in `find operators -iname "*.yaml"`; do
	oc create -f $i;
    done
}

KUBECONFIG=$KUBECONFIG apply

echo "Done, the operator may take a while to be ready"
echo "suggesting to wait a few seconds"
echo "trying a healthz loop for argocd"

ENDPOINT=https://openshift-gitops-server-openshift-gitops.apps.$CLUSTER_NAME.$ROUTE53_DOMAIN/healthz
echo $ENDPOINT
while true; do

    READY=$(curl -sk $ENDPOINT)
    if [ "$READY" == "ok" ]; then
	break;
    fi
    #echo $READY
    #date
    echo "Not ready, sleeping 5 secs"
    sleep 5
done



#./3.argo-login-and-get-cluster-info.sh
#echo "next script (3.argo-login-and-get-cluster-info.sh got called"
#./get-cluster-info.sh
#./get-argo-info.sh
