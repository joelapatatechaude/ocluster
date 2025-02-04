#!/bin/sh

source ./env.sh
source ~/.secrets/$MYDIR/route53
source ~/.secrets/$MYDIR/aws-creds

function delete {
    date
    openshift-install destroy cluster
}

delete
