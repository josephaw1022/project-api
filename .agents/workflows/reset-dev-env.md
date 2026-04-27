---
description: >
  Fully reset the local Project API development environment.
  Tears down the kind cluster and all certs, rebuilds the container image from source,
  and redeploys via Helm — leaving you with a clean, running cluster.
---

# Reset Dev Environment

Use this workflow when something is broken and you need a clean slate, or when you want
to validate the full setup path end-to-end after making structural changes.

## Steps

### 1. Activate Required Skills

Activate both the `local-dev-cluster` skill and the `build-and-load-api` skill before
proceeding. Their instructions govern the exact commands used below.

### 2. Full Teardown

Destroy the existing kind cluster and purge all locally generated certificates so nothing
carries over from the previous run:

```bash
./test/teardown.sh --all
```

Wait for the command to complete before moving on. Confirm no `kind-project-api-cluster-helm`
context remains:

```bash
kubectl config get-contexts
```

### 3. Rebuild the Container Image

Build a fresh `project-api:latest` image from the current source using Podman. Always build
from the `projects/` directory where the Dockerfile lives:

```bash
cd projects/
podman build -t project-api:latest .
cd ..
```

If the build fails, stop here and surface the error — do not attempt to bring up the cluster
with a stale or missing image.

### 4. Bring Up the Cluster

Run the Helm-based setup script. This creates the kind cluster, generates certs, loads the
image, installs the Helm chart, and applies the APIService — all in one shot:

```bash
./test/setup-helm.sh
```

### 5. Validate Self-Service Behavior

Once setup completes, run the self-service validation suite to confirm the Project API is
functioning correctly end-to-end:

```bash
./test/test-self-service-helm.sh
```

A passing run means Projects can be created, RBAC is applied automatically, and namespace
isolation is working as expected.

## Notes

- If `setup-helm.sh` fails mid-run, always run `./test/teardown.sh --all` before retrying —
  partial state causes misleading errors.
- The `kind-project-api-cluster-helm` context is what all `kubectl` commands in this repo
  use. Verify it exists with `kubectl config get-contexts` after setup.
