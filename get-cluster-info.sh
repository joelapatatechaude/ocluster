#!/bin/sh

source ./env.sh
source ~/.secrets/$MYDIR/route53


echo "Dashboard: https://console-openshift-console.apps.$CLUSTER_NAME.$ROUTE53_DOMAIN"
echo "Username:  kubeadmin"
echo "Password:  $(cat ~/.secrets/$MYDIR/kubeadmin-password)"

exit


function get_cluster_info {
    if [ $CLUSTER_NAME == "crc" ];
    then
	aa=https://console-openshift-console.apps-crc.testing/
    else
	aa=$(grep "Access the OpenShift web-console here:" ./$MYDIR/.openshift_install.log | tail -1 | awk -F 'web-console here: ' '{print $2}' )
    fi
    echo "Dashboard: ${aa::-1}"
    echo "Username : kubeadmin"
    echo "Password : $(cat $MYDIR/auth/kubeadmin-password)"
}
