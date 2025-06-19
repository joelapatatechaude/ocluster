#!/bin/sh
source ./env.sh
source ~/.secrets/$MYDIR/route53
set -a
source ~/.secrets/$MYDIR/aws-creds
set +a


IDS=$(cat aws-instances-to-resume.txt)
echo $IDS

aws ec2 start-instances --instance-ids $IDS --region $REGION

function test {
    echo "testing $1 kubernetes enpoint"
    while true; do
	echo "testing..."
	ANSWER=$(curl -k -s https://api.$CLUSTER_NAME.$ROUTE53_DOMAIN:6443/$1)
	echo $ANSWER
	if [ "$ANSWER" == "ok" ]
	then
	    break
	fi
	sleep 5;
    done
}

test livez
test readyz
