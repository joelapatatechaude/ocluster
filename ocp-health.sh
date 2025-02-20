#!/bin/sh
source ./env.sh
source ~/.secrets/$MYDIR/route53

echo "Need to be keep working. Essentially, the current curl respond ok"
echo "if it's up and reunning. Need to check what happens when not ready"
echo "then write the loop"

function test {
    echo "testing $1"
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
