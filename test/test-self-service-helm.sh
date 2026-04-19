#!/bin/bash
set -e

CLUSTER_NAME="project-api-cluster-helm"
USER_NAME="developer"
ADMIN_CONTEXT="kind-${CLUSTER_NAME}"
USER_CONTEXT="${USER_NAME}"

echo "Starting self-service validation (Helm)..."

# 1. Clear local cache to ensure fresh discovery
rm -rf ~/.kube/cache

# 2. Verify admin can see everything
echo "Verifying admin context..."
kubectl config use-context ${ADMIN_CONTEXT}

echo "Waiting for projects.project.io to be available in discovery..."
timeout=60
while ! kubectl api-resources --context ${ADMIN_CONTEXT} | grep -q "project.io"; do
  sleep 2
  timeout=$((timeout-2))
  if [ $timeout -le 0 ]; then
    echo "Timed out waiting for API discovery"
    exit 1
  fi
done

echo "Admin sees projects:"
kubectl get projects

# 3. Switch to developer user
echo "Switching to developer context..."
kubectl config use-context ${USER_CONTEXT}

# 4. Developer should see NO projects initially
echo "Developer projects (should be empty or filtered):"
kubectl get projects

# 5. Try to get a system project (should fail)
echo "Developer trying to get 'kube-system' project (should be forbidden):"
if kubectl get project kube-system 2>/dev/null; then
  echo "FAILURE: Developer could see kube-system!"
  exit 1
else
  echo "SUCCESS: Access to kube-system denied."
fi

# 6. Create a new project via ProjectRequest
PROJECT_NAME="dev-project-$(date +%s)"
echo "Creating project '${PROJECT_NAME}' as developer..."
kubectl create --validate=false -f - <<EOF
apiVersion: project.io/v1
kind: ProjectRequest
metadata:
  name: ${PROJECT_NAME}
EOF

# 7. Verify developer can see THEIR project
echo "Verifying developer can see '${PROJECT_NAME}':"
# Small sleep to allow RBAC to settle
sleep 5
if kubectl get project ${PROJECT_NAME} >/dev/null 2>&1; then
  echo "SUCCESS: Developer can see their new project."
  kubectl get project ${PROJECT_NAME}
else
  echo "FAILURE: Developer cannot see their own project!"
  # Debug: see what they CAN see
  echo "Current projects for developer:"
  kubectl get projects
  exit 1
fi

# 8. Verify developer has admin rights in the new namespace (try creating a deployment and service)
echo "Verifying admin rights in '${PROJECT_NAME}' (creating nginx deployment and service)..."
kubectl create -n ${PROJECT_NAME} -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
EOF

echo "SUCCESS: Nginx deployment and service created successfully."
echo "Developer has admin rights in the new project."

# 9. Verify developer still cannot see other projects
echo "Verifying developer still cannot see 'default' project:"
if kubectl get project default 2>/dev/null; then
  echo "FAILURE: Developer could see 'default' project!"
  exit 1
else
  echo "SUCCESS: Access to 'default' denied."
fi

echo "Self-service validation PASSED!"
kubectl config use-context ${ADMIN_CONTEXT}
