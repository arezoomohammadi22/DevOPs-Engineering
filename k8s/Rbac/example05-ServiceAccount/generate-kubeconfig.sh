#!/bin/bash

# Variables
SERVICE_ACCOUNT_NAME=$1
NAMESPACE=$2
KUBECONFIG_FILE=$3
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

if [ -z "$SERVICE_ACCOUNT_NAME" ] || [ -z "$NAMESPACE" ] || [ -z "$KUBECONFIG_FILE" ]; then
    echo "Usage: $0 <service-account-name> <namespace> <kubeconfig-output-file>"
    exit 1
fi

# Step 1: Check if ServiceAccount exists, create if it doesn't
kubectl get serviceaccount $SERVICE_ACCOUNT_NAME -n $NAMESPACE &>/dev/null
if [ $? -ne 0 ]; then
    echo "Creating ServiceAccount..."
    kubectl create serviceaccount $SERVICE_ACCOUNT_NAME -n $NAMESPACE
else
    echo "ServiceAccount already exists, continuing..."
fi

# Step 2: Create Secret for ServiceAccount
echo "Creating Secret for ServiceAccount..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${SERVICE_ACCOUNT_NAME}-token
  namespace: $NAMESPACE
  annotations:
    kubernetes.io/service-account.name: "$SERVICE_ACCOUNT_NAME"
type: kubernetes.io/service-account-token
EOF

# Step 3: Retrieve Token and Base64-Encoded CA Certificate
echo "Retrieving Token and CA certificate..."
sleep 5 # Wait for Kubernetes to populate the secret
SECRET_NAME=$(kubectl get secret -n $NAMESPACE | grep ${SERVICE_ACCOUNT_NAME}-token | awk '{print $1}')
TOKEN=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.token}' | base64 --decode)

# Use the ca.crt from the API server location
echo "Encoding CA certificate..."
CA_CERT_BASE64=$(cat /etc/kubernetes/pki/ca.crt | base64 -w 0)

# Step 4: Create kubeconfig file
echo "Generating kubeconfig file: $KUBECONFIG_FILE"
cat <<EOF > $KUBECONFIG_FILE
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $CA_CERT_BASE64
    server: $SERVER
  name: $CLUSTER_NAME
contexts:
- context:
    cluster: $CLUSTER_NAME
    user: $SERVICE_ACCOUNT_NAME
    namespace: $NAMESPACE
  name: ${SERVICE_ACCOUNT_NAME}-context
current-context: ${SERVICE_ACCOUNT_NAME}-context
users:
- name: $SERVICE_ACCOUNT_NAME
  user:
    token: $TOKEN
EOF

echo "Kubeconfig file $KUBECONFIG_FILE created successfully!"
