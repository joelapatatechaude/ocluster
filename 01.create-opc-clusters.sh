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
#!/bin/sh
# NOTES: Attempt to simplify everything.
# NOTES: Wondering if I can change the domain name to go under cszevaco.

source ~/.secrets/pullsecret
source ~/.secrets/$MYDIR/route53
source ~/.secrets/$MYDIR/aws-creds


function cluster {
    date
    cp install-config.yaml.template ./install-config.yaml
    sed -i "s/DOMAIN/$ROUTE53_DOMAIN/g" ./install-config.yaml
    sed -i "s/REGION/$REGION/g" ./install-config.yaml
    sed -i "s/CLUSTER_NAME/$CLUSTER_NAME/g" ./install-config.yaml
    sed -i "s/PULL_SECRET/$PULL_SECRET/g" ./install-config.yaml
    sed -i "s/MASTER_INSTANCE_TYPE/$MASTER_INSTANCE_TYPE/g" ./install-config.yaml
    sed -i "s/WORKER_INSTANCE_TYPE/$WORKER_INSTANCE_TYPE/g" ./install-config.yaml
    openshift-install create cluster
}

function trust {
    A=$(oc get configmap/kube-root-ca.crt -n openshift-service-ca -o jsonpath='{.data.ca\.crt}')
    echo "$A" | sudo tee /etc/pki/ca-trust/source/anchors/$(uuidgen)-$CLUSTER_NAME-OCPDEMO-ca.crt > /dev/null
    sudo update-ca-trust
    echo "done updating ca, you might need to restart your browser"
}


cluster

echo "skipping updating ca for now, fix code"
#KUBECONFIG=$MYDIR/auth/kubeconfig trust
#echo "done updating ca, you might need to restart your browser"
