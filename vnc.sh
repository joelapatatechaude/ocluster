#!/bin/bash
source `dirname $0`/env.sh
set -eux
echo "use it with namespace and vm name:"
echo "./$0 my-vm mynamespace port"

vm=$1
ns=$2
port=$3

echo $vm
echo $ns
echo $port



KUBECONFIG=$KUBECONFIG virtctl vnc $vm -n $ns --port $port --proxy-only &
remmina -c vnc://$vm.localhost:$port

wait
