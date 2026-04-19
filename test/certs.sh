#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
CERT_DIR="${DIR}/certs"
mkdir -p "${CERT_DIR}"

# CA
openssl genrsa -out "${CERT_DIR}/ca.key" 2048
openssl req -x509 -new -nodes -key "${CERT_DIR}/ca.key" -subj "/CN=project-api-ca" -days 3650 -out "${CERT_DIR}/ca.crt"

# Server Cert
openssl genrsa -out "${CERT_DIR}/server.key" 2048
openssl req -new -key "${CERT_DIR}/server.key" -subj "/CN=project-api.project-api-system.svc" -out "${CERT_DIR}/server.csr"

cat <<EOF > "${CERT_DIR}/extfile.cnf"
subjectAltName = DNS:project-api.project-api-system.svc, DNS:project-api.project-api-system.svc.cluster.local
EOF

openssl x509 -req -in "${CERT_DIR}/server.csr" -CA "${CERT_DIR}/ca.crt" -CAkey "${CERT_DIR}/ca.key" -CAcreateserial -out "${CERT_DIR}/server.crt" -days 365 -extfile "${CERT_DIR}/extfile.cnf"

echo "Certificates generated in ${CERT_DIR}"
