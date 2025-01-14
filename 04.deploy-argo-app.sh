#!/bin/bash

# uset set to auto export all the key value as env variable. Otherwise they remain bash variable, and are not consumed by things like envsubst
set -a
source ./env.sh
source ~/.secrets/$MYDIR/route53
set +a

echo "NEED TO DEPLOY APP FROM GITHUB MAYBE?"

function create_app_project {
    echo "creating app project for my cluster"
    cat <<EOF | oc apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: hub
  namespace: openshift-gitops
spec:
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
  destinations:
    - namespace: '*'
      server: '*'
  sourceRepos:
    - '*'
EOF
}

function deploy_app {
    for i in $(ls ${THEDIR:=cluster-go}/argo-app/*.yaml); do
	echo $i
	envsubst < $i | oc apply -f -
	#oc apply -f $i
    done
}


#source ~/.aws/route53

#source ~/.aws/github
#source ~/.aws/github-webhook
#CONTEXT=admin
#PROJECT=default

#private_repo_creds
#private_repo

#manual_webhook


KUBECONFIG=$KUBECONFIG  create_app_project

echo "next"
KUBECONFIG=$KUBECONFIG  deploy_app

echo "it could be I lost OpenShift connectivity, maybe due to auth changes, for a few minutes"

echo "I t could be I need to reapply the 03.argo-setup.sh to fix some permission agina..."
