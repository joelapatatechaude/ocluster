#!/bin/sh
source ./env.sh
source ~/.secrets/$MYDIR/route53

NSG=bookinfo-tosecure-istio

ENDPOINT="http://istio-ingressgateway-$NSG.apps.${CLUSTER_NAME}.${ROUTE53_DOMAIN}/productpage"

echo $ENDPOINT

siege \
    --no-parser \
    -c 5 \
    -d 0.5 \
    $ENDPOINT
