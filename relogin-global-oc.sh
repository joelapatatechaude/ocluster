#!/bin/sh
source ./env.sh
source ~/.secrets/$MYDIR/route53
set -eux
#echo "Relogin disabled at the moment in the sh script"
#exit

#KUBECONFIG=$KUBECONFIG oc login -u kubeadmin -p `cat ~/.secrets/$MYDIR/kubeadmin-password`  https://api.$CLUSTER_NAME.$ROUTE53_DOMAIN:6443
echo "first login locally"
./relogin.sh
echo "then login globally"
oc login $(./oc whoami --show-server) --token=$(./oc whoami --show-token)
