#!/bin/sh
source ./env.sh
set -a
source ~/.secrets/$MYDIR/aws-creds
set +a


IDS=$(./oc get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.providerID}{"\n"}{end}' | awk -F '///' '{print $2}' | awk -F '/' '{print $2}')
echo $IDS


echo "$IDS" > aws-instances-to-resume.txt
aws ec2 stop-instances --instance-ids $IDS --region $REGION
