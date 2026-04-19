#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
CLUSTER_NAME="project-api-cluster"
KUBECTL_CONTEXT="kind-${CLUSTER_NAME}"

if [[ "$1" == "--all" ]]; then
  echo "Deleting all Kind clusters and local certs..."
  kind delete clusters --all
  rm -rf "${DIR}/certs"
  echo "Full teardown complete."
  exit 0
fi

echo "Cleaning up Project API resources from cluster..."
kubectl --context "${KUBECTL_CONTEXT}" delete apiservice v1.project.io --ignore-not-found --interactive=false
kubectl --context "${KUBECTL_CONTEXT}" delete clusterrolebinding project-api-auth-delegator project-api-manager-binding --ignore-not-found --interactive=false
kubectl --context "${KUBECTL_CONTEXT}" delete clusterrole project-api-manager --ignore-not-found --interactive=false
kubectl --context "${KUBECTL_CONTEXT}" delete namespace project-api-system --ignore-not-found --wait=false --interactive=false
kubectl --context "${KUBECTL_CONTEXT}" delete rolebinding project-api-auth-reader -n kube-system --ignore-not-found --interactive=false

echo "Resource cleanup complete. Kind cluster and local certificates were preserved."
