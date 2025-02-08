
./03.5.deploy-eso-secrets.sh
./04.deploy-argo-app.sh lightspeed-operator.yaml
./04.deploy-argo-app.sh patch-operator.yaml
./04.deploy-argo-app.sh  patch-serviceaccount.yaml
./04.deploy-argo-app.sh external-secret-cluster.yaml
./04.deploy-argo-app.sh lightspeed.yaml
./04.deploy-argo-app.sh imagepuller-operator.yaml
./04.deploy-argo-app.sh devspaces-operator.yaml
./04.deploy-argo-app.sh devspaces-che.yaml
#Apply all gitops above via argocd

replace the cluster number (search for sandbox)
udpate secret-acs-endpoint with:
echo -n "central-acs-instance.apps.andromeda.sandbox63.opentlc.com:443" | base64 -w 0


./04.summer-camp-app-deploy.sh
#Sync everything. Note that devspaces comes from the hub project. Note: sync selenium too!

./oc apply -f  andromeda-secret-ssh-keys.yaml

#update the links below if sandbox has changed, then:
./oc apply  -f ~/gitlab-consulting/summer-camp-2023-github/links/

regenerate rox api token and update secret-rox-token.yaml file, commit and push (if I edit directly, argocd will overwrite)
Un-enforced the "Fixable.." policy via RHACS dashbaord


