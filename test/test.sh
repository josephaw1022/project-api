#!/bin/bash
set -e

KUBECTL_CONTEXT="kind-project-api-cluster"

echo "Listing existing projects..."
kubectl --context "${KUBECTL_CONTEXT}" get projects

echo "Creating a new project via ProjectRequest..."
cat <<EOF | kubectl --context "${KUBECTL_CONTEXT}" create -f -
apiVersion: project.io/v1
kind: ProjectRequest
metadata:
  name: demo-project
displayName: "My Demo Project"
description: "A project created via aggregated API"
EOF

echo "Verifying project exists..."
kubectl --context "${KUBECTL_CONTEXT}" get project demo-project

echo "Verifying underlying namespace exists..."
kubectl --context "${KUBECTL_CONTEXT}" get namespace demo-project

echo "Test complete!"
