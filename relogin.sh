#!/bin/sh
source ./env.sh
source ~/.secrets/$MYDIR/route53

KUBECONFIG=$KUBECONFIG oc login -u kubeadmin -p `cat ~/.secrets/$MYDIR/kubeadmin-password` https://api.$CLUSTER_NAME.$ROUTE53_DOMAIN:6443
