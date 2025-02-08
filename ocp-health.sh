#!/bin/sh
source ./env.sh
source ~/.secrets/$MYDIR/route53

echo "Need to be keep working. Essentially, the current curl respond ok"
echo "if it's up and reunning. Need to check what happens when not ready"
echo "then write the loop"

while true; do
    curl  https://api.$CLUSTER_NAME.$ROUTE53_DOMAIN:6443/livez
    curl  https://api.$CLUSTER_NAME.$ROUTE53_DOMAIN:6443/readyz
    sleep 5;
done
