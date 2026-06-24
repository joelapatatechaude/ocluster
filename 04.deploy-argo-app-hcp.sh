#!/bin/bash

# uset set to auto export all the key value as env variable. Otherwise they remain bash variable, and are not consumed by things like envsubst
set -a
source ./env.sh
source ~/.secrets/$MYDIR/route53
source ~/.secrets/smee-channel-master.txt
set +a

echo "NEED TO DEPLOY APP FROM GITHUB MAYBE?"

function deploy_bootstrap-hcp {
    i=./cluster-go/argo-app/bootstrap-app-of-apps-hcp.yaml
    echo $i
    envsubst < $i | oc apply -f -
}


function deploy_solo_app {
    THEFILE=$1
    if ! test -f $THEFILE; then
	echo "File $THEFILE does not exist."
	echo "exiting"
	exit
    else
	echo "File $THEFILE exits"
	echo "Deploying $THEFILE"
	envsubst < $THEFILE | oc apply -f -

    fi
}


KUBECONFIG=$KUBECONFIG deploy_bootstrap-hcp
KUBECONFIG=$KUBECONFIG deploy_solo_app cluster-go/argo-app/bootstrap-smee-helm.yaml
KUBECONFIG=$KUBECONFIG deploy_solo_app cluster-go/argo-app/essentials/webterminal-operator.yaml
KUBECONFIG=$KUBECONFIG deploy_solo_app cluster-go/argo-app/essentials/lightspeed.yaml
KUBECONFIG=$KUBECONFIG deploy_solo_app cluster-go/argo-app/essentials/lightspeed-operator.yaml

exit
