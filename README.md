# runkora examples

This repository holds runnable examples for [runkora](https://github.com/runkora/kora), an open source control plane for running agent factories in production.

## Quickstart

`make up` installs kora on a local k3d cluster. Run it from the repository root:

```bash
make up
```

See [`quickstart`](quickstart) for the prerequisites and the install stages.

## Examples

An example is a set of Kubernetes manifests that declare tenants, models, agents, triggers and roles for kora. Choose one when `make up` asks, or apply one later with `make example EXAMPLE=<name>`:

*   [`single-tenant`](single-tenant): One tenant with an agent that summarises pull requests.
*   [`multi-tenant`](multi-tenant): An engineering team and an SRE team, each in a separate tenant and repository.
*   [`factories/autofix`](factories/autofix): A factory of four agents that finds, verifies and fixes problems in a GitHub repository and hands a person the pull request.
*   [`factories/sre`](factories/sre): A factory that triages alerts in the cluster, sweeps its costs with OpenCost and proposes fixes as pull requests.
*   [`factories/feature`](factories/feature): A factory that turns a feature request into an approved spec, splits it into tasks and builds each task in a pull request.

Each example splits its manifests by owner:

*   `platform/` holds the tenants and models that the platform team owns.
*   A tenant folder, such as `tenant/` or `engineering/`, holds one team's agents, triggers and roles.

In production, each folder is a separate Git repository that a GitOps tool such as Argo CD or Flux applies to the cluster.

## Versions

`versions.mk` pins the kora release and the Istio, SPIRE, External Secrets Operator and k3s versions every example uses. The examples on `main` work with the latest kora release.

`make validate` checks every manifest against the Kubernetes, kora and External Secrets Operator schemas at those versions. CI runs it on every pull request. It needs `helm`, `kubectl`, `kubeconform` and Python with PyYAML.

## Documentation

*   [runkora docs](https://runkora.dev)
*   [Declarative resources](https://github.com/runkora/kora/blob/main/docs/guides/declarative-resources.md)
*   [Deploying runkora](https://github.com/runkora/kora/blob/main/docs/guides/deployment.md)

## License

Licensed under the Apache License, Version 2.0.
