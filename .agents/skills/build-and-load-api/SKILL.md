---
name: build-and-load-api
description: >
  Build the Project API Go code using Podman and load it directly into the local Kind cluster.
  Use when the user makes code changes and wants to deploy or test them in the local environment.
---

# Inner Loop: Build & Load API

When asked to "build and load the api", "deploy my changes", or similar requests to update the running cluster with new Go code, execute the following sequence:

## 1. Build the image
The user prefers `podman`. Build the Dockerfile from the `projects/` directory:
```bash
cd projects/
podman build -t project-api:latest .
```

## 2. Load the image into the local cluster
Push the newly built image into the nodes of the running `kind` cluster (which was stood up by `setup-helm.sh`):
```bash
kind load docker-image project-api:latest --name project-api-cluster-helm
```
*(Note: even though the user prefers podman, `kind load docker-image` relies on the `podman-docker` compatibility layer which is installed on the user's system).*

## 3. Restart the deployment
Trigger a rollout restart of the API server so Kubernetes pulls the fresh image:
```bash
kubectl --context kind-project-api-cluster-helm rollout restart deployment project-api -n project-api-system
```
