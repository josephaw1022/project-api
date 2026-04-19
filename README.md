# Project API

Project API provides a secure, self-service multi-tenancy layer for Kubernetes. It introduces the concept of **Projects**, which are specialized "views" of underlying Kubernetes `Namespaces`.

## Why Projects?

In a standard Kubernetes cluster, any user with `list namespaces` permissions can see every namespace in the cluster, which often leaks sensitive information about the cluster's organization and occupants.

Project API solves this by providing:

- **User Isolation**: Users can only see and interact with Projects they own or have been granted explicit access to.
- **Self-Service**: Users can create their own Projects (via `ProjectRequest`) without requiring cluster-wide `create namespace` permissions.
- **Automatic RBAC**: When a user creates a Project, the API server automatically injects a `project-admin` RoleBinding, granting them full management rights within that specific project.
- **Enhanced Security**: It prevents users from "scoping out" the cluster by hiding namespaces they don't have permission to access.

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

## Getting Started

All management and validation logic is located in the `test/` directory.

### Prerequisites

- `podman` (or Docker)
- `kind`
- `kubectl`
- `openssl`

### Installation

To provision a fresh Kind cluster, build the API server, and deploy all necessary manifests (APIService, CRDs, RBAC):

```bash
./test/setup.sh
```

### Validation

To run the automated self-service validation suite, which verifies project creation, ownership isolation, and RBAC injection:

```bash
./test/test-self-service.sh
```

## Project Structure

- `projects/`: Go source code for the aggregated API server.
- `test/`: Deployment manifests, setup/teardown scripts, and validation tests.
- `test/manifests/`: Kubernetes resource definitions for the API server and RBAC policies.
