#!/bin/bash
source ./env.sh
set -a
source ~/.secrets/$MYDIR/aws-creds
set +a

function wait_for_request {
    while true; do
	sleep 10
	STATUS=$(aws service-quotas get-requested-service-quota-change --request-id $REQ_ID --region $REGION | jq .RequestedQuota.Status -r)
	echo "Status at $(date) -> $STATUS"
	if [ $STATUS == "APPROVED" ]; then
	    break;
	fi
    done
}

function update_quota {
    CURRENT=$(aws service-quotas get-service-quota --service-code $S_CODE --quota-code $Q_CODE --region $REGION | jq .Quota.Value)
    echo CURRENT=$CURRENT
    echo DESIRED=$DESIRED
    if (( $(echo "$DESIRED > $CURRENT" |bc -l) )); then
	echo "CURRENT=$CURRENT DESIRED=$DESIRED need to request hit 'y' key to continue"
	read j
	if [ $j != "y" ]; then
	    echo "not requesting"
	    return
	fi
	echo "requesting at $(date)"
	REQ_ID=$(aws service-quotas request-service-quota-increase --service-code $S_CODE --quota-code $Q_CODE --region $REGION --desired-value $DESIRED | jq .RequestedQuota.Id -r)
	echo $REQ_ID
	REQ_ID=$REQ_ID REGION=$REGION wait_for_request
    else
	echo "limit ok"
    fi
}

# Maximum number of vCPUs assigned to the Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances.
#S_CODE=ec2 Q_CODE=L-1216C47A REGION=ap-southeast-2 DESIRED=9 update_quota

#IP address
S_CODE=ec2 Q_CODE=L-0263D0A3 REGION=ap-southeast-2 DESIRED=15 update_quota

# some cpu limite
S_CODE=ec2 Q_CODE=L-1216C47A REGION=ap-southeast-2 DESIRED=25 update_quota

