# The repository's entry point. Run every target from here.
#
# The quickstart's targets, such as make up, run the Makefile in quickstart/.
# make validate checks every manifest against the Kubernetes, kora and External
# Secrets Operator schemas at the versions in versions.mk. CI runs it on every
# pull request.

include versions.mk

# The kora-crds chart to read the schemas from. Point it at a local chart to
# validate against an unreleased version, e.g.
# make validate KORA_CRDS_CHART=../kora/charts/kora-crds.
KORA_CRDS_CHART ?= $(KORA_CHARTS)/kora-crds --version $(KORA_VERSION)

# The CRD schemas, converted to JSON Schema. Git ignores the folder.
SCHEMAS := .schemas

# The kustomizations make validate builds, one per example repository.
KUSTOMIZATIONS := single-tenant/platform single-tenant/tenant multi-tenant/platform multi-tenant/engineering multi-tenant/sre factories/autofix/platform factories/autofix/factory factories/sre/platform factories/sre/factory factories/sre/demo factories/feature/platform factories/feature/factory

KUBECONFORM := kubeconform -strict -summary \
	-schema-location default \
	-schema-location '$(SCHEMAS)/{{ .ResourceKind }}_{{ .ResourceAPIVersion }}.json'

# The quickstart targets this file forwards. Keep the list in step with the
# targets in quickstart/Makefile.
QUICKSTART_TARGETS := up tools cluster namespaces secrets istio spire data dex eso kora credentials providers example check-example apply-example ask-tunnel tunnel tunnel-stop status down clean

.PHONY: validate schemas $(QUICKSTART_TARGETS)

validate: schemas
	@for dir in $(KUSTOMIZATIONS); do \
		echo "$$dir"; \
		kubectl kustomize $$dir | $(KUBECONFORM) - || exit 1; \
	done
	@echo quickstart/manifests quickstart/providers
	@$(KUBECONFORM) quickstart/manifests quickstart/providers

# Renders the CRDs from the pinned charts and converts each to a JSON Schema
# named <kind>_<version>.json. See scripts/crd-schemas.py.
schemas:
	rm -rf $(SCHEMAS) && mkdir -p $(SCHEMAS)
	helm template kora-crds $(KORA_CRDS_CHART) --include-crds > $(SCHEMAS)/kora-crds.yaml
	helm template external-secrets external-secrets --repo https://charts.external-secrets.io \
		--version $(ESO_VERSION) --include-crds > $(SCHEMAS)/external-secrets.yaml
	python3 scripts/crd-schemas.py $(SCHEMAS) $(SCHEMAS)/kora-crds.yaml $(SCHEMAS)/external-secrets.yaml

# Runs a quickstart target in quickstart/. Variables set on the command line,
# such as EXAMPLE=multi-tenant, pass through.
$(QUICKSTART_TARGETS):
	@$(MAKE) --no-print-directory -C quickstart $@
