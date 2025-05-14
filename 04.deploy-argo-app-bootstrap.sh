#!/bin/bash

# uset set to auto export all the key value as env variable. Otherwise they remain bash variable, and are not consumed by things like envsubst
set -a
source ./env.sh
source ~/.secrets/$MYDIR/route53
set +a

echo "NEED TO DEPLOY APP FROM GITHUB MAYBE?"

function deploy_bootstrap {
    i=./cluster-go/argo-app/bootstrap-app-of-apps.yaml
    echo $i
    envsubst < $i | oc apply -f -
}

function deploy_app {
    for i in $(ls ${THEDIR:=cluster-go}/argo-app/*.yaml); do
	echo $i
	envsubst < $i | oc apply -f -
    done
}

function deploy_essential {
    for i in $(ls ${THEDIR:=cluster-go}/argo-app/essentials/*.yaml); do
	echo $i
	envsubst < $i | oc apply -f -
    done
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


#source ~/.aws/route53

#source ~/.aws/github
#source ~/.aws/github-webhook
#CONTEXT=admin
#PROJECT=default

#private_repo_creds
#private_repo

#manual_webhook

KUBECONFIG=$KUBECONFIG deploy_bootstrap
KUBECONFIG=$KUBECONFIG deploy_solo_app cluster-go/argo-app/bootstrap-smee-helm.yaml
KUBECONFIG=$KUBECONFIG deploy_essential
exit




if [ -n "$1" ]
then
    echo "First argument present: doing solo app"
    KUBECONFIG=$KUBECONFIG  deploy_solo_app $1
else
    echo "No argument present, deploy all in 2 seconds"
    sleep 2
    KUBECONFIG=$KUBECONFIG  deploy_app
fi
echo "it could be I lost OpenShift connectivity, maybe due to auth changes, for a few minutes"

echo "I t could be I need to reapply the 03.argo-setup.sh to fix some permission agina..."
