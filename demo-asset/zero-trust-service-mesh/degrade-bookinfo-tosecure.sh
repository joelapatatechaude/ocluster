#!/bin/sh
# THis script remove the autoinject from true to false, and remove the gateway and virutalservice, of bookinfo-tosecure. The idea is to have this demo flow:
#PREP:
# - deploy bookinfo-tosecure
# - degrade with this script
#Demo:
# - deploy bookinfo-tosecure-istio
# - enroll the namespace
# - explain the changes I am about to do through argocd diff and sync

NS=bookinfo-tosecure
NSG=${NS}-istio
function un_inject () {
    LIST=$($OC get deployments -n bookinfo-tosecure -o json | jq .items[].metadata.name -r)
    for dep in $LIST; do
	    $OC patch deployments $dep -n $NS --type=json -p='[{"op": "remove", "path": "/spec/template/metadata/annotations/sidecar.istio.io~1inject"}]'
	    #$OC patch deployments $dep -n $NS             -p '{"spec": {"template": {"metadata": {"annotations": {"sidecar.istio.io/inject": "false"}}}}}'
    done
}

function clean_resource () {
    echo $NS
    $OC delete gateway bookinfo-gateway -n $NS
    $OC delete virtualservices bookinfo -n $NS
    $OC delete smm default -n $NS
    $OC delete smcp basic -n $NSG
}


OC=./oc un_inject
OC=./oc clean_resource
