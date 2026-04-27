---
trigger: model_decision
description: Provides an overview of the Project API repository, its purpose, and its structure.
---

# Project API Repository Overview

This repository contains the **Project API**, a clean-room implementation of the OpenShift "Project" concept built for vanilla Kubernetes clusters. It provides a secure, self-service multi-tenancy layer.

## Key Concepts
- **Projects**: Specialized "views" of Kubernetes Namespaces.
- **Self-Service & Isolation**: Users can create their own namespaces and automatically become admins of them, but they cannot see or access namespaces they do not own.
- **API Aggregation**: The core mechanism is a custom Go application running as an aggregated API server (via an `APIService` resource). It intercepts requests to the `project.io` API group to enforce custom authorization and filtering.

## Repository Structure
- `projects/`: The Go source code for the custom aggregated API server.
- `charts/`: A Helm chart to deploy the Project API into a cluster.
- `test/`: Bash scripts for setup, validation tests, and teardown of a local `kind` cluster environment.
- `test/manifests/`: Raw Kubernetes manifests for deploying without Helm.

This project enables safe, isolated multi-tenancy without giving users cluster-wide access or creating operational bottlenecks for administrators.
