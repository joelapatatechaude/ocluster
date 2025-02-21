#!/bin/sh

source ./env.sh
source ~/.secrets/$MYDIR/smee-channels
source ~/.secrets/$MYDIR/route53


github_argocd () {
    echo "
Starting smee for github -> Argocd. Don't forget to check or update the git webhook at:
https://github.com/joelapatatechaude/ocluster/settings/hooks

WARNING: it seems like my own helm-gitrepo app (does not have helm logo) don't get auto-refresh. No idea why"
    smee -u https://smee.io/$SMEE_GITHUB_ARGOCD -t https://openshift-gitops-server-openshift-gitops.apps.$CLUSTER_NAME.$ROUTE53_DOMAIN/api/webhook

}

githubauthapp_rhdh () {
    echo "
Starting smee github app -> RHDH. Don't forget to check or update the gitapp webhook at:
https://github.com/organizations/rhdh-chris/settings/apps/rhdh-demo-chris
Note that I am not sure the webhook actually does anything or work. Currently I am getting 404 :(
"
    smee -u https://smee.io/$SMEE_GITHUBAUTHAPP_RHDH -t https://backstage-developer-hub-rhdh-operator.apps.$CLUSTER_NAME.$ROUTE53_DOMAIN
}

github_argocd &
githubauthapp_rhdh &
wait
