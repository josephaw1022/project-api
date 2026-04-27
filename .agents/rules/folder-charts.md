---
trigger: glob
description: Rules that apply specifically to the charts folder.
globs: charts/**
---

# Charts Folder Context

**Context**: This directory contains Helm charts used for deploying the Aggregated API Server and other related resources into a Kubernetes or OpenShift cluster.

## Rules
- When working in this directory, keep in mind that these are Helm templates and configurations.
- Follow standard Helm chart conventions and best practices.
- Ensure that any changes to templates are properly parameterized in `values.yaml` and keep the charts backwards compatible.
