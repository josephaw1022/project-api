---
description: >
  Inner-loop development cycle for the Project API Go server.
  Rebuilds the container image from updated source code, loads it into the running
  kind cluster, and restarts the deployment — all without tearing down the cluster.
---

# Iterate on API Changes

Use this workflow during active Go development on the `projects/` package. It lets you
push code changes into the running cluster quickly without a full teardown/setup cycle.

## Prerequisites

- The kind cluster is already running (stood up via `./test/setup-helm.sh`).
- The `kind-project-api-cluster-helm` kubectl context is active.
- You have made changes to Go source files under `projects/`.

If the cluster is not running, use the `/reset-dev-env` workflow first.

## Steps

### 1. Activate the `build-and-load-api` Skill

This skill governs the exact build, load, and restart commands used in steps 2–4.

### 2. Rebuild the Image

Build a new `project-api:latest` image from the modified source. The Dockerfile lives inside
`projects/`, so build from there:

```bash
cd projects/
podman build -t project-api:latest .
cd ..
```

Fix any build errors before continuing.

### 3. Load the Image into the Kind Cluster

Push the new image into all nodes of the running kind cluster. The `podman-docker`
compatibility layer makes the `kind load docker-image` command work with Podman:

```bash
kind load docker-image project-api:latest --name project-api-cluster-helm
```

### 4. Restart the Deployment

Trigger a rollout so Kubernetes pulls the freshly loaded image:

```bash
kubectl --context kind-project-api-cluster-helm rollout restart deployment project-api -n project-api-system
```

Wait for the rollout to finish:

```bash
kubectl --context kind-project-api-cluster-helm rollout status deployment project-api -n project-api-system
```

### 5. Re-run Self-Service Validation

Confirm your changes didn't break the core Project lifecycle (create → RBAC → isolation):

```bash
./test/test-self-service-helm.sh
```

Review any failures in context of the code changes made. If a test fails, check pod logs:

```bash
kubectl --context kind-project-api-cluster-helm logs -n project-api-system \
  -l app.kubernetes.io/name=project-api --tail=100
```

## Notes

- This workflow does **not** reinstall the Helm chart. If you changed anything in `charts/`
  (values, templates, CRDs), upgrade via `helm upgrade` or use `/reset-dev-env` instead.
- The image tag is always `project-api:latest`. Kind caches images, so the `kind load`
  step is required every time — skipping it means Kubernetes restarts onto the old image.
- The `project-api-system` namespace is where the API server pod lives. All `kubectl`
  commands targeting the API server should scope to that namespace.
