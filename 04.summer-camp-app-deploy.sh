#!/bin/bash



# uset set to auto export all the key value as env variable. Otherwise they remain bash variable, and are not consumed by things like envsubst
set -a
source ./env.sh
source ~/.secrets/$MYDIR/route53
source ~/.secrets/github-token
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
    done
}

function deploy_solo_app {
    THEFILE=cluster-go/argo-app/$1
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


function deploy_summer_camp {

    THEFILE=argoApp-summercamp.yaml
    echo "Deploying $THEFILE"
    envsubst < $THEFILE | oc apply -f -
}

function auth_token_summercamp {

    ARGO_SERVER=$(KUBECONFIG=$KUBECONFIG oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')
    echo $ARGO_SERVER
    ARGO_PASSWORD=$(KUBECONFIG=$KUBECONFIG oc get secret openshift-gitops-cluster -n openshift-gitops -o json | jq -r '.data."admin.password"' | base64 -d)
    argocd login --username admin --password $ARGO_PASSWORD $ARGO_SERVER --config=$ARGO_CONFIG --insecure
    argocd repo add https://github.com/itil-sa/summer-camp --username $GITHUB_ITIL_SA_USERNAME --password $GITHUB_ITIL_SA_TOKEN --insecure --server $ARGO_SERVER --config=$ARGO_CONFIG

}

function patch_acs_health {
    KUBECONFIG=$KUBECONFIG oc patch argocds openshift-gitops -n openshift-gitops --type='merge' --patch-file ArgoCD-patch_acs-health.yaml
}

KUBECONFIG=$KUBECONFIG auth_token_summercamp

KUBECONFIG=$KUBECONFIG patch_acs_health

KUBECONFIG=$KUBECONFIG deploy_summer_camp

#KUBECONFIG=$KUBECONFIG  create_app_project

#if [ -n "$1" ]
#then
#    echo "First argument present: doing solo app"
#    KUBECONFIG=$KUBECONFIG  deploy_solo_app $1
#else
#    echo "No argument present, deploy all"
#    KUBECONFIG=$KUBECONFIG  deploy_app
#fi
#echo""
#echo "it could be I lost OpenShift connectivity, maybe due to auth changes, for a few minutes"

#echo "I t could be I need to reapply the 03.argo-setup.sh to fix some permission agina..."
