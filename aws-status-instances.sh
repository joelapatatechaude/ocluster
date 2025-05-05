#!/bin/sh
source ./env.sh
source ~/.secrets/$MYDIR/route53
set -a
source ~/.secrets/$MYDIR/aws-creds
set +a


IDS=$(cat aws-instances-to-resume.txt)
echo $IDS

aws ec2 describe-instance-status --instance-ids $IDS

