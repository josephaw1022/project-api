---
trigger: glob
description: Rules that apply specifically to the projects folder.
globs: projects/**
---

# Projects Folder Context

**Context**: This directory contains the Go code for our Aggregated API Server that handles the `Project` resources for us. It relies on standard Kubernetes and OpenShift patterns (like the `pkg/apis` and `pkg/registry` structure) to serve the API.

## Rules
- When working in this directory, keep in mind that this is an aggregated API server written in Go.
- Follow standard Go and Kubernetes API machinery conventions.
