#!/bin/sh
source ./env.sh
set -a
source ~/.secrets/$MYDIR/aws-creds
set +a


IDS=$(./oc get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.providerID}{"\n"}{end}' | awk -F '///' '{print $2}' | awk -F '/' '{print $2}')
echo $IDS

echo "Remember I only implemented this for on ID. If more, I need to update this script, use aws ec2 ... --dry-run to make it easier. Maybe I don't need a loop after all."
echo "type a key to continue"
read a

echo "$IDS" > aws-instances-to-resume.txt
aws ec2 stop-instances --instance-ids $IDS
