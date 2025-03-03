#!/bin/sh

source ./env.sh

KUBECONFIG=$KUBECONFIG oc get projects -o name | grep hello-quarkus > ns-to-delete

echo "going to delete those namespaces:"
cat ns-to-delete

echo ""
echo "press a key to continue"
read a
for i in `cat ns-to-delete`; do
    echo "deleting $i in 0 sec"
    sleep 0
    KUBECONFIG=$KUBECONFIG oc delete $i
done
