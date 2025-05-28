#!/bin/bash
source `dirname $0`/env.sh
#set -eux
echo "use it with namespace and vm name:"
echo "./$0 my-vm -n mynamespace"



KUBECONFIG=$KUBECONFIG virtctl vnc $@ --port 5901 --proxy-only &
remmina -c vnc://localhost:5901
REMMPID=$!
echo "test"
echo $REMMPID

wait
