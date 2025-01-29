#!/bin/sh
source ./env.sh
source ~/.secrets/$MYDIR/route53

ENDPOINT="http://istio-ingressgateway-service-mesh-control-plane.apps.${CLUSTER_NAME}.${ROUTE53_DOMAIN}/productpage"

echo $ENDPOINT

siege \
    --no-parser \
    -c 5 \
    -d 0.5 \
    $ENDPOINT



#echo "siege --no-parser http://istio-ingressgateway-mesh2-system.apps.singapore-cluster.${ROUTE53_DOMAIN}/productpage"
