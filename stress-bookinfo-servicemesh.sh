#!/bin/sh
source ./env.sh
source ~/.secrets/$MYDIR/route53

NSG=bookinfo-servicemesh-istio

ENDPOINT="http://istio-ingressgateway-$NSG.apps.${CLUSTER_NAME}.${ROUTE53_DOMAIN}/productpage"

echo "Going to hit the following endpoint:"
echo $ENDPOINT
echo "press a key to start siege"
read a

siege \
    --no-parser \
    -c 5 \
    -d 0.5 \
    $ENDPOINT

