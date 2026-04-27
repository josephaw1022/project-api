---
description: >
  Triage unexpected behavior or errors in the running Project API.
  Systematically collects cluster state, pod logs, APIService health, and RBAC bindings
  to produce a structured diagnostic report and surface root cause candidates.
---

# Triage API Issue

Use this workflow when the Project API behaves unexpectedly — Projects can't be listed,
ProjectRequests fail, RBAC isn't applied, or the aggregated API endpoint is unreachable.

## Context

This repo implements a Kubernetes Aggregated API Server. Most issues fall into one of
four buckets:

1. **API Server pod crash / restart loop** — the Go process is failing to start or panicking.
2. **APIService degraded** — the `kube-apiserver` can't reach the Project API service.
3. **RBAC misconfiguration** — the ClusterRole or binding for the API server's service
   account is missing or incorrect.
4. **Logic bug** — the server starts fine but returns wrong data or rejects valid requests.

## Steps

### 1. Gather Pod Health

Check whether the API server pod is running and how many times it has restarted:

```bash
kubectl --context kind-project-api-cluster-helm get pods -n project-api-system -o wide
```

### 2. Pull Pod Logs

Collect the last 200 lines from the running pod. If the pod is crash-looping, also pull
logs from the previous container:

```bash
kubectl --context kind-project-api-cluster-helm logs -n project-api-system \
  -l app.kubernetes.io/name=project-api --tail=200

# If crash-looping, grab the previous container's logs:
kubectl --context kind-project-api-cluster-helm logs -n project-api-system \
  -l app.kubernetes.io/name=project-api --previous --tail=200
```

### 3. Check APIService Status

The `APIService` object tells you whether `kube-apiserver` considers the Project API
reachable. A `False` or `Unknown` condition here is the most common source of 503s:

```bash
kubectl --context kind-project-api-cluster-helm get apiservice v1alpha1.project.io -o yaml
```

Look at `.status.conditions` — `Available: True` is required for the API to work.

### 4. Inspect the Service and Endpoints

Verify the `Service` in `project-api-system` has healthy endpoints behind it:

```bash
kubectl --context kind-project-api-cluster-helm get svc,endpoints -n project-api-system
```

A service with no ready endpoints means no Pod is passing health checks.

### 5. Check RBAC for the API Server ServiceAccount

The API server's service account needs a `ClusterRole` that lets it impersonate users
and access namespaces. Confirm the binding exists:

```bash
kubectl --context kind-project-api-cluster-helm get clusterrolebindings \
  -l app.kubernetes.io/name=project-api

kubectl --context kind-project-api-cluster-helm get clusterroles \
  -l app.kubernetes.io/name=project-api -o yaml
```

### 6. Reproduce the Failing Operation

Run the self-service test in verbose mode to capture the exact API call and response
that is failing:

```bash
./test/test-self-service-helm.sh
```

If the test itself doesn't reveal enough detail, use `kubectl` directly as a non-admin
user (the test script switches contexts) and watch the pod logs in a second terminal:

```bash
kubectl --context kind-project-api-cluster-helm logs -n project-api-system \
  -l app.kubernetes.io/name=project-api --follow
```

### 7. Produce Diagnostic Report

After gathering the above information, create an artifact named `triage-report.md` that
summarizes:

- **Symptom**: What the user observed or what test failed.
- **Cluster State**: Pod status, restart count, APIService condition.
- **Log Highlights**: Key error lines from pod logs.
- **Root Cause Candidates**: Which of the four buckets above this falls into and why.
- **Recommended Fix**: Specific next steps (e.g., fix RBAC, fix Go panic, redeploy cert).

## Notes

- The `kind-project-api-cluster-helm` context is the Helm-deployed cluster. If the user
  set up with `setup.sh` (raw manifests), the context is `kind-project-api-cluster` instead.
- TLS cert issues between `kube-apiserver` and the Project API service surface as
  `x509: certificate signed by unknown authority` in the APIService conditions — check
  `./test/certs/` to confirm the CA bundle is in sync.
- RBAC errors in the API server logs often look like "forbidden" messages even when the
  *end user* has correct permissions — these usually indicate the *API server's own
  service account* is missing a permission.
