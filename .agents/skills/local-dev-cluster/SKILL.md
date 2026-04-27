---
name: local-dev-cluster
description: >
  Manage the local kind cluster environment for the Project API, including setup and full teardown using Helm.
  Use when the user wants to spin up, recreate, or delete the local development cluster.
---

# Managing the Local Dev Cluster

When asked to spin up, reset, or tear down the local development cluster for the Project API, follow these specific instructions:

## 1. Setting up the cluster
Always use the helm-based setup script:
```bash
./test/setup-helm.sh
```
This script handles standing up the `kind` cluster, generating required certificates, and deploying the Project API using the Helm chart located in `charts/project-api`.

## 2. Tearing down the cluster
When getting rid of the cluster (especially the one created by `setup-helm.sh`), you must perform a full teardown using the `--all` flag:
```bash
./test/teardown.sh --all
```
This ensures that all Kind clusters are deleted and any locally generated certificates (in `test/certs/`) are removed, leaving a completely clean slate.
