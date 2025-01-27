#!/bin/sh
source ./env.sh

echo "Trying to get to the bottom of an issue, try this:"
echo "First login int argocd with the argocd admin user/password"
echo "run this script"
echo "If it works (If I don't get some authorization issue when deploying an argo-app), then see if I can automate that bit"
echo "If it doesnt work, keep investigating"
echo "remember, the issue, is that usually, I need to run this script a second time at a later stage, essentailly when I see the authorization messages in argocd interface"
echo "exiting"
exit



function patch_label {
    KUBECONFIG=$KUBECONFIG oc patch argocds openshift-gitops -n openshift-gitops --type='merge' -p '{"spec":{"applicationInstanceLabelKey":"argocd.argoproj.io/instance"}}'
}

function patch_sub_health {
    KUBECONFIG=$KUBECONFIG oc patch argocds openshift-gitops -n openshift-gitops --type='merge' --patch-file ArgoCD-patch_sub_health.yaml
}

function fix_permissions {
    KUBECONFIG=$KUBECONFIG oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller
    KUBECONFIG=$KUBECONFIG oc adm policy add-role-to-user cluster-admin system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller
}

KUBECONFIG=$KUBECONFIG patch_label
KUBECONFIG=$KUBECONFIG patch_sub_health
KUBECONFIG=$KUBECONFIG fix_permissions
