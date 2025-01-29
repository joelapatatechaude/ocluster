#!/bin/sh
source ./env.sh
source ~/.secrets/$MYDIR/route53

NS=bookinfo-tosecure

ENDPOINT="https://bookinfo-$NS.apps.${CLUSTER_NAME}.${ROUTE53_DOMAIN}/productpage"



echo $ENDPOINT

siege \
    --no-parser \
    -c 5 \
    -d 0.5 \
    $ENDPOINT
