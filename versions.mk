# Versions shared by every example. Each example's Makefile includes this file.
# Override any of them on the command line, e.g. make up KORA_VERSION=0.11.0.

# The kora release the examples install. Both charts share the version.
KORA_VERSION ?= 0.11.1
KORA_CHARTS ?= oci://ghcr.io/runkora/charts

# kora supports Istio 1.30 and 1.31. The operator's preflight rejects any other version.
ISTIO_VERSION ?= 1.31.1

# The spiffe/spire chart 0.30.2 ships SPIRE 1.15.3.
SPIRE_CRDS_VERSION ?= 0.6.1
SPIRE_VERSION ?= 0.30.2

# External Secrets Operator creates the Secrets the examples reference, from
# the quickstart's credential store or your secret manager.
ESO_VERSION ?= 2.14.0

# The opencost chart 2.5.33 ships OpenCost 1.121.3. The sre example's cost
# sweeper reads it through OpenCost's MCP server.
OPENCOST_VERSION ?= 2.5.33

# The kora charts require Kubernetes 1.34 or later.
K3S_IMAGE ?= rancher/k3s:v1.36.4-k3s1
