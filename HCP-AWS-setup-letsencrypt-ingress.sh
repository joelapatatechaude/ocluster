#!/usr/bin/env bash
set -euo pipefail

DOMAIN="cszevaco.com"

# Source AWS credentials and cluster env

source ./env.sh  # must export: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION, CLUSTER_NAME
source ~/.secrets/$MYDIR/route53
source ~/.secrets/$MYDIR/aws-creds

DOMAIN=$ROUTE53_DOMAIN
echo $DOMAIN
echo $AWS_ACCESS_KEY_ID

: "${AWS_ACCESS_KEY_ID:?AWS_ACCESS_KEY_ID is not set}"
: "${AWS_SECRET_ACCESS_KEY:?AWS_SECRET_ACCESS_KEY is not set}"
: "${AWS_DEFAULT_REGION:?AWS_DEFAULT_REGION is not set}"
: "${CLUSTER_NAME:?CLUSTER_NAME is not set}"

HOSTED_ZONE_ID=$(./oc get dns cluster -o jsonpath='{.spec.publicZone.id}')
INGRESS_DOMAIN=$(./oc get ingresscontroller default -n openshift-ingress-operator -o jsonpath='{.status.domain}')

echo "=== Let's Encrypt ingress certificate setup ==="
echo "  Domain:        ${DOMAIN}"
echo "  Cluster:       ${CLUSTER_NAME}"
echo "  Ingress:       *.${INGRESS_DOMAIN}"
echo "  Route53 zone:  ${HOSTED_ZONE_ID}"
echo "  AWS region:    ${AWS_DEFAULT_REGION}"
echo ""


# --- Step 0: Patch cert-manager to use recursive nameservers ---
# HCP clusters have a private Route53 zone (ai.hcp.$DOMAIN) that shadows the
# public zone (hcp.$DOMAIN). cert-manager's default authoritative-NS discovery
# picks up the private zone's nameservers, which refuse direct queries.
# Using public recursive nameservers avoids this split-horizon DNS issue.
echo "[0/5] Patching cert-manager to use public recursive nameservers..."
./oc patch certmanager cluster --type=merge -p '
spec:
  controllerConfig:
    overrideArgs:
    - --dns01-recursive-nameservers=8.8.8.8:53,1.1.1.1:53
    - --dns01-recursive-nameservers-only=true
'

echo "    Waiting for cert-manager controller to restart..."
./oc rollout status deployment/cert-manager -n cert-manager --timeout=60s

# --- Step 1: AWS credentials secret for cert-manager ---
echo "[1/5] Creating AWS credentials secret in cert-manager namespace..."
./oc create secret generic aws-route53-credentials \
  -n cert-manager \
  --from-literal=access-key-id="${AWS_ACCESS_KEY_ID}" \
  --from-literal=secret-access-key="${AWS_SECRET_ACCESS_KEY}" \
  --dry-run=client -o yaml | ./oc apply -f -


# --- Step 2: ClusterIssuer with Route53 DNS-01 solver ---
echo "[2/5] Creating Let's Encrypt ClusterIssuer (Route53 DNS-01)..."
./oc apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-route53-production
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: cschmitz@redhat.com
    privateKeySecretRef:
      name: letsencrypt-route53-production
    solvers:
      - dns01:
          route53:
            region: ${AWS_DEFAULT_REGION}
            hostedZoneID: ${HOSTED_ZONE_ID}
            accessKeyIDSecretRef:
              name: aws-route53-credentials
              key: access-key-id
            secretAccessKeySecretRef:
              name: aws-route53-credentials
              key: secret-access-key
EOF

echo "    Waiting for ClusterIssuer to become ready..."
for i in $(seq 1 30); do
  ready=$(./oc get clusterissuer letsencrypt-route53-production -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  if [[ "${ready}" == "True" ]]; then
    echo "    ClusterIssuer is ready."
    break
  fi
  if [[ "${i}" -eq 30 ]]; then
    echo "    WARNING: ClusterIssuer not ready after 60s. Check: ./oc describe clusterissuer letsencrypt-route53-production"
  fi
  sleep 2
done


# --- Step 3: Wildcard Certificate for ingress ---
echo "[3/5] Creating wildcard Certificate for *.${INGRESS_DOMAIN}..."
./oc apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ingress-certificate-production
  namespace: openshift-ingress
spec:
  secretName: ingress-certificate-production
  issuerRef:
    name: letsencrypt-route53-production
    kind: ClusterIssuer
  commonName: "*.${INGRESS_DOMAIN}"
  dnsNames:
    - "*.${INGRESS_DOMAIN}"
EOF

echo "    Waiting for Certificate to be issued (this can take 1-2 minutes)..."
for i in $(seq 1 60); do
  ready=$(./oc get certificate ingress-certificate-production -n openshift-ingress -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  if [[ "${ready}" == "True" ]]; then
    echo "    Certificate issued successfully!"
    break
  fi
  if [[ "${i}" -eq 60 ]]; then
    echo "    WARNING: Certificate not ready after 2 minutes."
    echo "    Debug with: ./oc describe certificate ingress-certificate-production -n openshift-ingress"
    echo "                ./oc describe certificaterequest -n openshift-ingress"
    echo "                ./oc logs -n cert-manager -l app=cert-manager"
    exit 1
  fi
  sleep 2
done


# --- Step 4: Patch IngressController to use the new cert ---
echo "[4/5] Patching IngressController to use Let's Encrypt certificate..."
./oc patch ingresscontroller default -n openshift-ingress-operator \
  --type=merge \
  -p '{"spec":{"defaultCertificate":{"name":"ingress-certificate-production"}}}'

echo ""
echo "=== [5/5] Verification ==="
echo ""
./oc get certificate -n openshift-ingress
echo ""
./oc get secret ingress-certificate-production -n openshift-ingress \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject -issuer -dates
echo ""
echo "Done. Test with: curl -v https://console-openshift-console.${INGRESS_DOMAIN} 2>&1 | grep -E 'issuer|subject|SSL'"
