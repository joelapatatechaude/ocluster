#!/bin/sh
# THis script remove the authoriattion policy of the ns, so that I can get argocd to re-add it.

NS=bookinfo-compromised
NSG=$NS-istio

function patch () {
    $OC patch smcp basic -n $NSG --type='merge' -p '{"spec": {"security": {"controlPlane": {"mtls": false}}}}'
    $OC patch smcp basic -n $NSG --type='merge' -p '{"spec": {"security": {"dataPlane":    {"mtls": false}}}}'
}

function clean_resource () {
    echo $NS
    $OC delete authorizationpolicy ratings -n $NS
}

OC=./oc clean_resource
OC=./oc patch
