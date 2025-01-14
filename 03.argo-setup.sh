#!/bin/sh
source ./env.sh


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
