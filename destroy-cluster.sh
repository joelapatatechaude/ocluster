#!/bin/sh

source ./env.sh
set -a
source ~/.secrets/$MYDIR/route53
source ~/.secrets/$MYDIR/aws-creds
set +a

function delete {
    date
    openshift-install destroy cluster --log-level debug
}

delete
