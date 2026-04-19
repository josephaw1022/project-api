#!/bin/bash
set -e

# Configuration
CLUSTER_NAME="project-api-cluster"
NAMESPACE="project-api-system"
IMAGE_NAME="josephaw1022/project-api"
KUBECTL_CONTEXT="kind-${CLUSTER_NAME}"

BUILD_IMAGE=false
PUSH_IMAGE=false

for arg in "$@"; do
  if [ "$arg" == "--build" ]; then
    BUILD_IMAGE=true
  fi
  if [ "$arg" == "--push" ]; then
    PUSH_IMAGE=true
  fi
done

echo "Creating Kind cluster..."
# Use podman if available, otherwise docker
export KIND_EXPERIMENTAL_PROVIDER=podman
if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  kind create cluster --name ${CLUSTER_NAME}
else
  echo "Cluster '${CLUSTER_NAME}' already exists, skipping creation."
fi

# Point to the kind cluster
kubectl config use-context ${KUBECTL_CONTEXT}

if [ "$BUILD_IMAGE" = true ]; then
  # Generate a unique tag based on the current timestamp to force image refresh
  IMAGE_TAG=$(date +%s)
  FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

  echo "Building project-api image..."
  echo "Using image: ${FULL_IMAGE}"
  # Build the image locally
  podman build -t ${FULL_IMAGE} ../projects

  # For kind, we can also load the image locally to speed things up
  echo "Loading image into Kind..."
  kind load docker-image ${FULL_IMAGE} --name ${CLUSTER_NAME}

  # Update deployment manifest with the new image tag, surgically replacing only the image part
  sed -i "s|${IMAGE_NAME}:.*|${FULL_IMAGE}|" manifests/deployment.yaml
else
  # Resolve FULL_IMAGE from the current manifest
  FULL_IMAGE=$(grep "image: ${IMAGE_NAME}" manifests/deployment.yaml | awk '{print $2}' | tr -d '"')
  echo "Using existing image from manifest: ${FULL_IMAGE}"
fi

if [ "$PUSH_IMAGE" = true ]; then
  echo "Pushing image ${FULL_IMAGE} to Docker Hub..."
  podman push ${FULL_IMAGE}
fi

echo "Generating certificates with SANs..."
CERT_DIR="./certs"
mkdir -p ${CERT_DIR}

cat <<EOF > ${CERT_DIR}/openssl.cnf
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no
[req_distinguished_name]
CN = project-api.${NAMESPACE}.svc
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = project-api
DNS.2 = project-api.${NAMESPACE}
DNS.3 = project-api.${NAMESPACE}.svc
EOF

openssl req -newkey rsa:2048 -nodes -keyout ${CERT_DIR}/tls.key -x509 -days 365 -out ${CERT_DIR}/tls.crt -config ${CERT_DIR}/openssl.cnf

echo "Creating namespace and certificates secret..."
kubectl --context "${KUBECTL_CONTEXT}" apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
---
apiVersion: v1
kind: Secret
metadata:
  name: project-api-certs
  namespace: ${NAMESPACE}
type: kubernetes.io/tls
data:
  tls.crt: $(cat ${CERT_DIR}/tls.crt | base64 -w0)
  tls.key: $(cat ${CERT_DIR}/tls.key | base64 -w0)
EOF

echo "Applying manifests..."
# CA bundle for APIService
CA_BUNDLE=$(cat ${CERT_DIR}/tls.crt | base64 -w0)
sed -i "s/caBundle: .*/caBundle: ${CA_BUNDLE}/" manifests/apiservice.yaml

kubectl --context "${KUBECTL_CONTEXT}" apply -f manifests/apiservice.yaml
kubectl --context "${KUBECTL_CONTEXT}" apply -f manifests/deployment.yaml

echo "Waiting for deployment..."
kubectl --context "${KUBECTL_CONTEXT}" rollout status deployment/project-api -n ${NAMESPACE} --timeout=120s

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
kubectl --context "${KUBECTL_CONTEXT}" create clusterrolebinding ${USER_NAME}-self-provisioner --clusterrole=self-provisioner --user=${USER_NAME}
kubectl --context "${KUBECTL_CONTEXT}" create clusterrolebinding ${USER_NAME}-project-viewer --clusterrole=project-viewer --user=${USER_NAME}

echo "Setup complete! Test user '${USER_NAME}' is ready."
echo "Use 'kubectl config use-context ${USER_NAME}' to test as the user."
