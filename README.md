# Project API

Project API provides a secure, self-service multi-tenancy layer for Kubernetes. It introduces the concept of **Projects**, which are specialized "views" of underlying Kubernetes `Namespaces`.

## Why Projects?

Projects are the primary way to enable a user to create a namespace, be an admin of the namespaces they've created, and modify or delete them without having access to or visibility of other namespaces in the cluster.

In a standard Kubernetes cluster, any user with `list namespaces` permissions can see every namespace in the cluster, which often leaks sensitive information about the cluster's organization and occupants.

Project API solves this by providing:

- **User Isolation**: Users can only see and interact with Projects they own or have been granted explicit access to.
- **Self-Service**: Users can create their own Projects (via `ProjectRequest`) without requiring cluster-wide `create namespace` permissions.
- **Automatic RBAC**: When a user creates a Project, the API server automatically injects a `project-admin` RoleBinding, granting them full management rights within that specific project.
- **Enhanced Security**: It prevents users from "scoping out" the cluster by hiding namespaces they don't have permission to access.

## Getting Started

All management and validation logic is located in the `test/` directory.

### Prerequisites

- `podman` (or Docker)
- `kind`
- `kubectl`
- `openssl`

### Installation

There are two ways to deploy the Project API:

#### Option 1: Helm Chart (Recommended)
This uses the Helm chart for a standardized deployment.

```bash
# Setup cluster and install via Helm
./test/setup-helm.sh

# Validate self-service via Helm context
./test/test-self-service-helm.sh
```

#### Option 2: Raw Manifests
This is useful for local development and debugging.

```bash
# Provision Kind cluster, build API server, and deploy manifests
./test/setup.sh

# Validate self-service
./test/test-self-service.sh
```

### Teardown

To remove the Project API resources from the cluster while keeping the Kind cluster and certificates intact:

```bash
./test/teardown.sh
```

To completely obliterate all Kind clusters and clear all local certificates:

```bash
./test/teardown.sh --all
```

## Project Structure

- `projects/`: Go source code for the aggregated API server.
- `charts/`: Helm chart for deploying the Project API.
- `test/`: Deployment scripts, setup/teardown logic, and validation tests.
- `test/manifests/`: Raw Kubernetes resource definitions.

## Inspiration & Heritage

This project is a clean-room "rip" of the **Project** concept from the **OpenShift** ecosystem. While OpenShift provides powerful multi-tenancy out of the box, it is often tightly coupled with the rest of the platform. 

The goal of this repository is to decouple this logic and enable the **exact same project experience** on any **vanilla Kubernetes cluster**.

This implementation was built by analyzing and porting logic from several key OpenShift repositories:
- [**openshift/api**](https://github.com/openshift/api): For the core `Project` and `ProjectRequest` schemas.
- [**openshift/origin**](https://github.com/openshift/origin): For the behavioral logic and E2E test patterns.
- [**openshift/cluster-openshift-apiserver-operator**](https://github.com/openshift/cluster-openshift-apiserver-operator): For understanding how the API server is configured and observed.
- [**openshift/apiserver-library-go**](https://github.com/openshift/apiserver-library-go): For authorization scoping and filtering patterns.

## How it Works

The "only your projects" isolation is made possible by the **Kubernetes API Aggregation** layer. 

1. **APIService Resource**: We register the `project.io` group using an `APIService` resource.
2. **Routing**: This resource tells the main Kubernetes API server to route all requests for projects and projectrequests to a specific **Service**.
3. **Go Implementation**: That Service points to our custom **Go application**, which runs as a standard **Deployment** in the cluster.
4. **Custom Logic**: Because our Go app is the one handling the requests, it can intercept the calls and perform its own authorization checks. It only returns the projects (namespaces) that the calling user is actually allowed to see, creating the seamless isolation experience.
