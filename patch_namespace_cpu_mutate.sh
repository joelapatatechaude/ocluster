#!/bin/sh
source ./env.sh

NAMESPACES_TO_PATCH="
doesnt-exists
cert-manager
cert-manager-operator
external-secrets
gitlab-system
multicluster-engine
open-cluster-management
open-cluster-management-agent
open-cluster-management-agent-addon
open-cluster-management-global-set
open-cluster-management-hub
openshift-devspaces
openshift-gitops
openshift-monitoring
openshift-operators
openshift-storage
openshift-terminal
rhacs-operator
stackrox
stackrox-secured
zeadmin-devspaces
"

for i in $NAMESPACES_TO_PATCH; do
    echo "patching $i"
    KUBECONFIG=$KUBECONFIG oc label namespace/$i mutate-cpu=true
done
exit
CURRENT_NAMESPACES=$($MYDIR/auth/kubeconfig oc get namespaces -o custom-columns='NAME:.metadata.name')
