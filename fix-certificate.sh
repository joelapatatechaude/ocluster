#!/bin/sh

source ./env.sh
source ~/.secrets/$MYDIR/route53

./oc get csr -o name | xargs ./oc adm certificate approve

