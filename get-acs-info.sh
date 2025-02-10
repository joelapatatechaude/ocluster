#!/bin/sh

source ./env.sh
source ~/.secrets/$MYDIR/route53

NS=stackrox


PASS=$(KUBECONFIG=$KUBECONFIG oc -n $NS get secret central-htpasswd -o go-template='{{index .data "password" | base64decode}}')
echo "URL : https://central-$NS.apps.$CLUSTER_NAME.$ROUTE53_DOMAIN"
echo "User: admin"
echo "Pwd : $PASS"
