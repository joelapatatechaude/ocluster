#!/bin/sh


source ./env.sh

if [ $CLUSTER_TYPE == "bm" ];
   then
       echo "Nothing to do for bare metal"
       echo "exiting...."
       exit
else
    echo "going to run the script"
fi
