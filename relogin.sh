#!/bin/sh
set -eux
source ./env.sh
source ~/.secrets/$MYDIR/route53

#echo "Relogin disabled at the moment in the sh script"
#exit

KUBECONFIG=$KUBECONFIG oc login -u `cat ~/.secrets/$MYDIR/admin-username` -p `cat ~/.secrets/$MYDIR/admin-password`  https://api.$CLUSTER_NAME.$ROUTE53_DOMAIN:6443
