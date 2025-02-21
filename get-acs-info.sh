#!/bin/sh

source ./env.sh
source ~/.secrets/$MYDIR/route53

DEFAULT_NS=stackrox
FOUND_NS=$(KUBECONFIG=$KUBECONFIG oc get central -A -o custom-columns=:metadata.namespace --no-headers)
NS=$FOUND_NS
echo $NS

PASS=$(KUBECONFIG=$KUBECONFIG oc -n $NS get secret central-htpasswd -o go-template='{{index .data "password" | base64decode}}')
echo "URL : https://central-$NS.apps.$CLUSTER_NAME.$ROUTE53_DOMAIN"
echo "User: admin"
echo "Pwd : $PASS"
