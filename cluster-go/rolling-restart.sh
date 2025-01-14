#!/bin/sh
NAMESPACE="openshift-gitops"

pods=$(oc get pod -n $NAMESPACE | grep Running | awk '{print $1}')
echo $pods

for i in $pods; do
    echo "deleting pod $i"
    oc delete pod $i -n $NAMESPACE
    echo "waiting an extra 10 sec"
    sleep 10
done
