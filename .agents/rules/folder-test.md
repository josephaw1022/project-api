---
trigger: glob
description: Rules that apply specifically to the test folder.
globs: test/**
---

# Test Folder Context

**Context**: This directory contains shell scripts, manifests, and configurations used for setting up, testing, and tearing down local environments (like a local Kubernetes cluster using Kind).

## Rules
- When working in this directory, keep in mind that these are test automation and environment setup scripts.
- Ensure any modifications to testing scripts properly handle setup and teardown phases without leaving orphaned resources.
- Follow standard shell scripting best practices (e.g., proper error handling, quoting variables).
