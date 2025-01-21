#!/bin/sh

source ./env.sh

function delete {
    date
    openshift-install destroy cluster
}

delete
