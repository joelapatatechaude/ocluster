#!/bin/sh
source ./env.sh

KUBECONFIG=$KUBECONFIG oc login -u kubeadmin -p `cat ~/.secrets/$MYDIR/kubeadmin-password` https://api.$CLUSTER_NAME.cszevaco.com:6443
