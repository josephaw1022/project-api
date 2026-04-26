#!/bin/bash
set -e

# Configuration
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
CLUSTER_NAME="project-api-cluster-helm"
NAMESPACE="project-api-system"
CHART_PATH="${DIR}/../charts/project-api"
RELEASE_NAME="project-api"
KUBECTL_CONTEXT="kind-${CLUSTER_NAME}"

echo "Creating Kind cluster..."
export KIND_EXPERIMENTAL_PROVIDER=podman
if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  kind create cluster --name ${CLUSTER_NAME}
else
  echo "Cluster '${CLUSTER_NAME}' already exists, skipping creation."
fi




# Create namespace if it doesn't exist
kubectl --context "${KUBECTL_CONTEXT}" get namespace ${NAMESPACE} >/dev/null 2>&1 || kubectl --context "${KUBECTL_CONTEXT}" create namespace ${NAMESPACE}

echo "Installing Project API via Helm..."
# We use the default values which generate certificates automatically
helm --kube-context "${KUBECTL_CONTEXT}" upgrade --install ${RELEASE_NAME} ${CHART_PATH} \
  --namespace ${NAMESPACE} \
  --wait \
  --timeout 300s

echo "Setting up test user: developer..."
USER_NAME="developer"
USER_DIR="./users/${USER_NAME}"
mkdir -p ${USER_DIR}

# Generate Key and CSR
openssl genrsa -out ${USER_DIR}/${USER_NAME}.key 2048
openssl req -new -key ${USER_DIR}/${USER_NAME}.key -out ${USER_DIR}/${USER_NAME}.csr -subj "/CN=${USER_NAME}"

# Submit CSR (non-interactively)
kubectl --context "${KUBECTL_CONTEXT}" delete csr ${USER_NAME} --ignore-not-found --interactive=false
cat <<EOF | kubectl --context "${KUBECTL_CONTEXT}" apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${USER_NAME}
spec:
  request: $(cat ${USER_DIR}/${USER_NAME}.csr | base64 -w0)
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF

# Approve CSR
kubectl --context "${KUBECTL_CONTEXT}" certificate approve ${USER_NAME}

# Get the certificate
kubectl --context "${KUBECTL_CONTEXT}" get csr ${USER_NAME} -o jsonpath='{.status.certificate}' | base64 -d > ${USER_DIR}/${USER_NAME}.crt

# Set kubectl credentials and context
kubectl config set-credentials ${USER_NAME} --client-certificate=${USER_DIR}/${USER_NAME}.crt --client-key=${USER_DIR}/${USER_NAME}.key --embed-certs=true
kubectl config set-context ${USER_NAME} --cluster=${KUBECTL_CONTEXT} --user=${USER_NAME}

# Grant self-provisioner and project-viewer permissions to the developer
# Using the namespaced ClusterRole names from the Helm chart
# The Helm chart prefixes ClusterRoles with the fullname (which is release name if not overridden)
kubectl --context "${KUBECTL_CONTEXT}" create clusterrolebinding ${USER_NAME}-self-provisioner --clusterrole=${RELEASE_NAME}-self-provisioner --user=${USER_NAME} --dry-run=client -o yaml | kubectl --context "${KUBECTL_CONTEXT}" apply -f -
kubectl --context "${KUBECTL_CONTEXT}" create clusterrolebinding ${USER_NAME}-project-viewer --clusterrole=${RELEASE_NAME}-viewer --user=${USER_NAME} --dry-run=client -o yaml | kubectl --context "${KUBECTL_CONTEXT}" apply -f -

echo "Setup complete! Test user '${USER_NAME}' is ready."
echo "Use 'kubectl config use-context ${USER_NAME}' to test as the user."
