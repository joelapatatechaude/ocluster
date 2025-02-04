#!/bin/sh
source ./env.sh
set -a
source ~/.secrets/$MYDIR/aws-creds
set +a


IDS=$(cat aws-instances-to-resume.txt)
echo $IDS

echo "Remember I only implemented this for on ID. If more, I need to update this script, use aws ec2 ... --dry-run to make it easier. Maybe I don't need a loop after all."
echo "type a key to continue"
read a

aws ec2 start-instances --instance-ids $IDS
