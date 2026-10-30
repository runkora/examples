# Installs kora on a local k3d cluster. Each target is one stage of the
# install, in the order kora needs them. make up runs every stage. Run a single
# stage to see what it does, and inspect the cluster before the next one.

include ../versions.mk

CLUSTER := kora-quickstart
CONTEXT := k3d-$(CLUSTER)

# The SPIFFE trust domain SPIRE, Istio and kora share. It is part of every
# workload identity kora issues. Choose it before you install. Changing it later
# is an identity migration.
TRUST_DOMAIN := quickstart.runkora.test

# Keys and passwords generated on your machine. Git ignores them.
SECRETS := .secrets

# The webhook tunnel's process ID, URL and log. Git ignores the folder.
TUNNEL_DIR := .tunnel

# The examples make example applies. For each example: the tenants its
# platform repository declares, its tenant repositories and the user to sign in
# as.
EXAMPLES := single-tenant multi-tenant factories/autofix factories/sre factories/feature
TENANTS_single-tenant := example
REPOS_single-tenant := tenant
SIGN_IN_single-tenant := admin@local.runkora.io
TENANTS_multi-tenant := engineering sre
REPOS_multi-tenant := engineering sre
SIGN_IN_multi-tenant := engineering-admin@local.runkora.io or sre-admin@local.runkora.io
TENANTS_factories/autofix := autofix
REPOS_factories/autofix := factory
SIGN_IN_factories/autofix := autofix-admin@local.runkora.io
TENANTS_factories/sre := oncall
REPOS_factories/sre := factory
SIGN_IN_factories/sre := oncall-admin@local.runkora.io
TENANTS_factories/feature := feature
REPOS_factories/feature := factory
SIGN_IN_factories/feature := feature-admin@local.runkora.io

# The webhook signing secrets the examples' trigger sources read, one per
# tenant and provider. make credentials generates each one.
WEBHOOK_SECRETS := example-github-webhook engineering-github-webhook engineering-slack-webhook sre-alertmanager-webhook autofix-github-webhook oncall-github-webhook oncall-alertmanager-webhook feature-github-webhook

# The credentials you fill in from .env.example. The install runs without the
# file, and make credentials skips each value that is not set.
-include .env
export OPENROUTER_API_KEY EXA_API_KEY GITHUB_APP_PRIVATE_KEY_FILE

KUBECTL := kubectl --context $(CONTEXT)
HELM := helm --kube-context $(CONTEXT)
HELM_INSTALL := $(HELM) upgrade --install --wait --timeout 10m

# Creates a Secret or ConfigMap, or updates it when it already exists.
define apply
$(KUBECTL) -n $(1) create $(2) --dry-run=client -o yaml | $(KUBECTL) apply -f -
endef

.PHONY: up tools cluster namespaces secrets istio spire data dex eso kora credentials providers example check-example apply-example ask-tunnel tunnel tunnel-stop alert status down clean

up: tools cluster namespaces secrets istio spire data dex eso kora credentials providers example ask-tunnel

# Checks the tools the install uses.
tools:
	@for tool in docker k3d kubectl helm openssl; do \
		command -v $$tool >/dev/null || { echo "Missing $$tool. See README.md for the prerequisites."; exit 1; }; \
	done

# Creates the k3d cluster from k3d.yaml.
#
# Every meshed pod and every kora service that watches a ConfigMap opens
# inotify instances. The Docker VM's default limit of 128 is too low for kora.
# The k3d nodes share the VM's kernel. A privileged container raises the limit
# for all of them. The limit resets when the Docker VM restarts.
cluster:
	docker run --rm --privileged alpine:3.20 sysctl -w fs.inotify.max_user_instances=1024
	k3d cluster list $(CLUSTER) >/dev/null 2>&1 || k3d cluster create --config k3d.yaml --image $(K3S_IMAGE)

# Creates the namespaces, with the labels kora-system needs before kora starts.
namespaces:
	$(KUBECTL) apply -f manifests/namespaces.yaml

# The RSA key kora signs its access tokens with.
$(SECRETS)/signing.key:
	@mkdir -p $(SECRETS)
	openssl genrsa -out $@ 4096

# The Postgres and Redis passwords and the frontend session secret.
$(SECRETS)/db-password $(SECRETS)/redis-password $(SECRETS)/session-secret:
	@mkdir -p $(SECRETS)
	openssl rand -hex 32 | tr -d '\n' > $@

# The key kora-triggers encrypts webhook signing secrets with: 32 random bytes, base64 encoded.
$(SECRETS)/triggers-key:
	@mkdir -p $(SECRETS)
	openssl rand -base64 32 | tr -d '\n' > $@

# A webhook signing secret. Give the same value to the provider when you
# connect it. Slack issues its own: replace the file's contents with it and
# run make credentials.
$(SECRETS)/%-webhook:
	@mkdir -p $(SECRETS)
	openssl rand -hex 32 | tr -d '\n' > $@

# Stores the generated values in the cluster. kora reads kora-secrets and
# kora-frontend-secrets. The chart does not create them.
secrets: $(SECRETS)/signing.key $(SECRETS)/db-password $(SECRETS)/redis-password $(SECRETS)/session-secret $(SECRETS)/triggers-key
	$(call apply,kora-data,secret generic postgres --from-file=password=$(SECRETS)/db-password)
	$(call apply,kora-data,secret generic redis --from-file=password=$(SECRETS)/redis-password)
	$(call apply,kora-system,secret generic kora-secrets \
		--from-file=DB_PASSWORD=$(SECRETS)/db-password \
		--from-file=REDIS_PASSWORD=$(SECRETS)/redis-password \
		--from-file=KORA_TOKEN_SIGNING_KEY=$(SECRETS)/signing.key \
		--from-file=KORA_TRIGGERS_ENCRYPTION_KEY=$(SECRETS)/triggers-key)
	$(call apply,kora-system,secret generic kora-frontend-secrets --from-file=BFF_SESSION_SECRET=$(SECRETS)/session-secret)

# Istio in sidecar mode with the CNI plugin. kora's services and agents run in
# the mesh.
istio:
	$(HELM_INSTALL) istio-base oci://ghcr.io/istio/release/charts/base --version $(ISTIO_VERSION) \
		-n istio-system --create-namespace
	$(HELM_INSTALL) istio-cni oci://ghcr.io/istio/release/charts/cni --version $(ISTIO_VERSION) \
		-n istio-system -f values/istio-cni.yaml
	$(HELM_INSTALL) istiod oci://ghcr.io/istio/release/charts/istiod --version $(ISTIO_VERSION) \
		-n istio-system -f values/istiod.yaml --set meshConfig.trustDomain=$(TRUST_DOMAIN)

# SPIRE issues a SPIFFE identity to every kora workload and agent.
spire:
	$(HELM_INSTALL) spire-crds spire-crds --repo https://spiffe.github.io/helm-charts-hardened \
		--version $(SPIRE_CRDS_VERSION) -n spire-system --create-namespace
	$(HELM_INSTALL) spire spire --repo https://spiffe.github.io/helm-charts-hardened \
		--version $(SPIRE_VERSION) -n spire-system -f values/spire.yaml \
		--set global.spire.trustDomain=$(TRUST_DOMAIN) \
		--set global.spire.clusterName=$(CLUSTER)

# Postgres and Redis for kora.
data:
	$(KUBECTL) apply -f manifests/data
	$(KUBECTL) -n kora-data rollout status statefulset/postgres --timeout 5m
	$(KUBECTL) -n kora-data rollout status deployment/redis --timeout 5m

# Dex and its user directory, for signing in.
dex:
	$(KUBECTL) apply -f manifests/dex
	$(KUBECTL) -n dex rollout status deployment/glauth --timeout 5m
	$(KUBECTL) -n dex rollout status deployment/dex --timeout 5m

# External Secrets Operator and the store it reads the quickstart's
# credentials from. The examples read every credential through an
# ExternalSecret.
eso:
	$(HELM_INSTALL) external-secrets external-secrets --repo https://charts.external-secrets.io \
		--version $(ESO_VERSION) -n external-secrets --create-namespace
	$(KUBECTL) apply -f manifests/credentials

# The two kora charts. kora-crds installs the custom resources. kora installs
# the operator and the platform services, and its pre-install hook creates the
# database schema.
kora:
	$(HELM_INSTALL) kora-crds $(KORA_CHARTS)/kora-crds --version $(KORA_VERSION) -n kora-system
	$(HELM_INSTALL) kora $(KORA_CHARTS)/kora --version $(KORA_VERSION) -n kora-system \
		-f values/kora.yaml --set global.trustDomain=$(TRUST_DOMAIN)

# Stores each credential set in .env and each generated webhook signing secret
# as a Secret. The recipes print the variable names only. The values stay out
# of your terminal.
#
# The OpenRouter key goes to kora-system, where its provider lives. The rest go
# to kora-credentials, where the examples' ExternalSecret resources read them
# from.
credentials: $(addprefix $(SECRETS)/,$(WEBHOOK_SECRETS))
	@if [ -n "$$OPENROUTER_API_KEY" ]; then \
		echo "OPENROUTER_API_KEY -> Secret openrouter in kora-system"; \
		$(call apply,kora-system,secret generic openrouter --from-literal=apiKey="$$OPENROUTER_API_KEY"); \
		$(KUBECTL) -n kora-system label secret openrouter runkora.io/inference-provider=true --overwrite; \
	fi
	@if [ -n "$$EXA_API_KEY" ]; then \
		echo "EXA_API_KEY -> Secret sre-exa in kora-credentials"; \
		$(call apply,kora-credentials,secret generic sre-exa --from-literal=apiKey="$$EXA_API_KEY"); \
	fi
	@if [ -n "$$GITHUB_APP_PRIVATE_KEY_FILE" ]; then \
		echo "GITHUB_APP_PRIVATE_KEY_FILE -> Secrets engineering-github-app, autofix-github-app, oncall-github-app and feature-github-app in kora-credentials"; \
		$(call apply,kora-credentials,secret generic engineering-github-app --from-file=key.pem="$$GITHUB_APP_PRIVATE_KEY_FILE"); \
		$(call apply,kora-credentials,secret generic autofix-github-app --from-file=key.pem="$$GITHUB_APP_PRIVATE_KEY_FILE"); \
		$(call apply,kora-credentials,secret generic oncall-github-app --from-file=key.pem="$$GITHUB_APP_PRIVATE_KEY_FILE"); \
		$(call apply,kora-credentials,secret generic feature-github-app --from-file=key.pem="$$GITHUB_APP_PRIVATE_KEY_FILE"); \
	fi
	@for name in $(WEBHOOK_SECRETS); do \
		echo "$(SECRETS)/$$name -> Secret $$name in kora-credentials"; \
		$(call apply,kora-credentials,secret generic $$name --from-file=secret=$(SECRETS)/$$name); \
	done

# The model providers you uncommented in providers/. They are for the quickstart
# only. The examples' models route to them by name.
providers:
	@if grep -qs '^kind: InferenceProvider' providers/*.yaml; then \
		$(KUBECTL) apply -f providers; \
	else \
		echo "No model provider is enabled. Uncomment one in providers/ and run make providers."; \
	fi

# Asks which example to run on the cluster, then applies it. Set EXAMPLE to
# skip the question, e.g. make up EXAMPLE=multi-tenant or EXAMPLE=none. Without
# a terminal to ask in, it applies single-tenant.
example:
	@example="$(EXAMPLE)"; \
	if [ -z "$$example" ] && [ -t 0 ]; then \
		echo; \
		echo "Which example should run on the cluster?"; \
		echo "  1) single-tenant  One tenant with one agent. Needs a model provider only."; \
		echo "  2) multi-tenant   Two teams with four use cases. Also needs an Exa key and a GitHub App."; \
		echo "  3) autofix        A factory that finds, verifies and fixes bugs. Needs a GitHub App and a repository."; \
		echo "  4) sre            A factory that triages alerts and proposes fixes. Needs a GitHub App and a repository."; \
		echo "  5) feature        A factory that specs, plans and builds features. Needs a GitHub App and a repository."; \
		echo "  6) none           Apply one later with make example."; \
		printf "Choose 1, 2, 3, 4, 5 or 6 [1]: "; read choice; \
		case "$$choice" in 2) example=multi-tenant;; 3) example=factories/autofix;; 4) example=factories/sre;; 5) example=factories/feature;; 6) example=none;; *) example=single-tenant;; esac; \
	fi; \
	[ "$${example:-single-tenant}" = none ] || $(MAKE) --no-print-directory apply-example EXAMPLE=$${example:-single-tenant}

# Checks what an example needs before it applies, lists anything missing and
# stops. multi-tenant needs an Exa API key, a GitHub App private key and the
# App's settings in its github connection.
check-example:
ifeq ($(EXAMPLE),multi-tenant)
	@missing=0; \
	if [ -z "$$EXA_API_KEY" ]; then \
		echo "multi-tenant: set EXA_API_KEY in quickstart/.env."; missing=1; \
	fi; \
	if [ ! -f "$$GITHUB_APP_PRIVATE_KEY_FILE" ]; then \
		echo "multi-tenant: set GITHUB_APP_PRIVATE_KEY_FILE in quickstart/.env to your GitHub App's private key file."; missing=1; \
	fi; \
	if grep -q 'owner: example-org' ../multi-tenant/engineering/shared/connections/github.yaml; then \
		echo "multi-tenant: set app_id, installation_id and owner in multi-tenant/engineering/shared/connections/github.yaml."; missing=1; \
	fi; \
	if [ $$missing = 1 ]; then \
		echo "See multi-tenant/README.md. Then run make credentials example EXAMPLE=multi-tenant."; exit 1; \
	fi
endif
ifeq ($(EXAMPLE),factories/autofix)
	@missing=0; \
	if [ ! -f "$$GITHUB_APP_PRIVATE_KEY_FILE" ]; then \
		echo "autofix: set GITHUB_APP_PRIVATE_KEY_FILE in quickstart/.env to your GitHub App's private key file."; missing=1; \
	fi; \
	if grep -q 'owner: example-org' ../factories/autofix/factory/shared/github-connection.yaml; then \
		echo "autofix: set app_id, installation_id and owner in factories/autofix/factory/shared/github-connection.yaml."; missing=1; \
	fi; \
	if grep -rqF -e 'example-org/example-repo' -e 'example-autofix[bot]' ../factories/autofix/factory/triggers; then \
		echo "autofix: replace example-org/example-repo and example-autofix[bot] in factories/autofix/factory/triggers with your repository and your App's bot user."; missing=1; \
	fi; \
	if [ $$missing = 1 ]; then \
		echo "See factories/autofix/README.md. Then run make credentials example EXAMPLE=factories/autofix."; exit 1; \
	fi
endif
ifeq ($(EXAMPLE),factories/sre)
	@missing=0; \
	if [ ! -f "$$GITHUB_APP_PRIVATE_KEY_FILE" ]; then \
		echo "sre: set GITHUB_APP_PRIVATE_KEY_FILE in quickstart/.env to your GitHub App's private key file."; missing=1; \
	fi; \
	if grep -q 'owner: example-org' ../factories/sre/factory/shared/github-connection.yaml; then \
		echo "sre: set app_id, installation_id and owner in factories/sre/factory/shared/github-connection.yaml."; missing=1; \
	fi; \
	if grep -rqF -e 'example-org/example-deploy' -e 'example-sre[bot]' ../factories/sre/factory/triggers; then \
		echo "sre: replace example-org/example-deploy and example-sre[bot] in factories/sre/factory/triggers with your deploy repository and your App's bot user."; missing=1; \
	fi; \
	if [ $$missing = 1 ]; then \
		echo "See factories/sre/README.md. Then run make credentials example EXAMPLE=factories/sre."; exit 1; \
	fi
endif
ifeq ($(EXAMPLE),factories/feature)
	@missing=0; \
	if [ ! -f "$$GITHUB_APP_PRIVATE_KEY_FILE" ]; then \
		echo "feature: set GITHUB_APP_PRIVATE_KEY_FILE in quickstart/.env to your GitHub App's private key file."; missing=1; \
	fi; \
	if grep -q 'owner: example-org' ../factories/feature/factory/shared/github-connection.yaml; then \
		echo "feature: set app_id, installation_id and owner in factories/feature/factory/shared/github-connection.yaml."; missing=1; \
	fi; \
	if grep -rqF -e 'example-org/example-repo' -e 'example-feature[bot]' ../factories/feature/factory/triggers; then \
		echo "feature: replace example-org/example-repo and example-feature[bot] in factories/feature/factory/triggers with your repository and your App's bot user."; missing=1; \
	fi; \
	if [ $$missing = 1 ]; then \
		echo "See factories/feature/README.md. Then run make credentials example EXAMPLE=factories/feature."; exit 1; \
	fi
endif

# Applies an example: its platform repository first, then each tenant
# repository once the operator has created the tenant's namespace.
apply-example: check-example
	@case " $(EXAMPLES) " in *" $(EXAMPLE) "*) ;; *) echo "Unknown example $(EXAMPLE). Choose one of: $(EXAMPLES)."; exit 1;; esac
	$(KUBECTL) apply -k ../$(EXAMPLE)/platform
	@for tenant in $(TENANTS_$(EXAMPLE)); do \
		for i in $$(seq 60); do \
			$(KUBECTL) get namespace kora-tenant-$$tenant >/dev/null 2>&1 && break; \
			[ $$i = 60 ] && { echo "The operator did not create kora-tenant-$$tenant. Check the operator logs."; exit 1; }; \
			sleep 2; \
		done; \
	done
ifeq ($(EXAMPLE),factories/sre)
	$(HELM_INSTALL) opencost opencost --repo https://opencost.github.io/opencost-helm-chart \
		--version $(OPENCOST_VERSION) -n opencost --create-namespace -f values/opencost.yaml
endif
	@for repo in $(REPOS_$(EXAMPLE)); do \
		$(KUBECTL) apply -k ../$(EXAMPLE)/$$repo || exit 1; \
	done
ifeq ($(EXAMPLE),factories/sre)
	@echo "Setting the cluster connection's caCert to this cluster's CA"
	@{ printf 'spec:\n  caCert: |\n'; \
		$(KUBECTL) -n kora-tenant-oncall get configmap kube-root-ca.crt -o jsonpath='{.data.ca\.crt}' | sed 's/^/    /'; \
	} | $(KUBECTL) -n kora-tenant-oncall patch connection cluster --type merge --patch-file /dev/stdin
	$(KUBECTL) apply -k ../factories/sre/demo
endif
	@echo
	@echo "$(EXAMPLE) is running."
	@echo "  Console:  http://kora.localhost:9880"
	@echo "  Sign in:  $(SIGN_IN_$(EXAMPLE)), password \"password\""
	@echo

# Shows the releases, the tenants, the providers and models, what the
# examples declared in every tenant, and any pod that is not running.
status:
	$(HELM) list -A
	$(KUBECTL) get koratenants
	$(KUBECTL) -n kora-system get inferenceproviders,virtualmodels
	$(KUBECTL) get environments,agents.runkora.io,triggersources,triggers.runkora.io,policyroles,mcpservers,connections,externalsecrets -A
	$(KUBECTL) get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded

# Asks whether to start the webhook tunnel. Set TUNNEL=yes or TUNNEL=no to
# skip the question. Without a terminal to ask in, it starts no tunnel.
ask-tunnel:
	@answer="$(TUNNEL)"; \
	if [ -z "$$answer" ] && [ -t 0 ]; then \
		echo; \
		printf "Start a tunnel so webhook triggers fire? It makes the cluster's API reachable from the internet. [y/N]: "; \
		read answer; \
	fi; \
	case "$$answer" in y|Y|yes) $(MAKE) --no-print-directory tunnel;; esac

# Starts a Cloudflare quick tunnel to the kora API, then prints the webhook URL
# for every trigger source in the cluster. Paste each URL and its secret into
# the provider's webhook settings. The URL changes each time the tunnel starts.
#
# The tunnel forwards to the gateway on localhost:9880 as api.kora.localhost.
# The webhook path accepts only events signed with the source's secret. The
# console and the API still need a sign-in.
tunnel: tunnel-stop
	@command -v cloudflared >/dev/null || { echo "Missing cloudflared. Install it with brew install cloudflared."; exit 1; }
	@mkdir -p $(TUNNEL_DIR)
	@nohup cloudflared tunnel --no-autoupdate --url http://localhost:9880 \
		--http-host-header api.kora.localhost > $(TUNNEL_DIR)/cloudflared.log 2>&1 & echo $$! > $(TUNNEL_DIR)/pid
	@for i in $$(seq 30); do \
		url=$$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' $(TUNNEL_DIR)/cloudflared.log | head -1); \
		[ -n "$$url" ] && break; sleep 1; \
	done; \
	[ -n "$$url" ] || { echo "The tunnel did not start. See $(TUNNEL_DIR)/cloudflared.log."; exit 1; }; \
	echo "$$url" > $(TUNNEL_DIR)/url; \
	echo; echo "Tunnel: $$url"; echo; \
	$(KUBECTL) get triggersources -A -o jsonpath='{range .items[*]}{.metadata.namespace}|{.metadata.name}|{.spec.provider}|{.status.webhookPath}|{.spec.signingSecretRef.name}|{.spec.signingSecretRef.key}{"\n"}{end}' | \
	while IFS='|' read -r ns name provider webhook_path secret key; do \
		echo "$$ns/$$name ($$provider)"; \
		if [ -z "$$webhook_path" ]; then echo "  Not ready: the source has no webhook path yet. Run make tunnel again once it is Ready."; continue; fi; \
		echo "  URL:     $$url$$webhook_path"; \
		echo "  Secret:  kubectl --context $(CONTEXT) -n $$ns get secret $$secret -o jsonpath='{.data.$$key}' | base64 -d"; \
	done; \
	echo; echo "Stop it with make tunnel-stop."

# Stops the webhook tunnel.
tunnel-stop:
	@if [ -f $(TUNNEL_DIR)/pid ]; then kill $$(cat $(TUNNEL_DIR)/pid) 2>/dev/null || true; rm -f $(TUNNEL_DIR)/pid $(TUNNEL_DIR)/url; fi

# Posts the alert Alertmanager would send for the sre example's crash-looping
# checkout pod. STATUS=resolved posts the resolution. The alert reaches kora on
# localhost and needs no tunnel.
STATUS ?= firing
alert:
	@path=$$($(KUBECTL) -n kora-tenant-oncall get triggersource alertmanager -o jsonpath='{.status.webhookPath}'); \
	[ -n "$$path" ] || { echo "The sre example's alertmanager source is not ready. Run make example EXAMPLE=factories/sre."; exit 1; }; \
	now=$$(date -u +%Y-%m-%dT%H:%M:%SZ); \
	printf '%s' '{"version":"4","status":"$(STATUS)","receiver":"kora","groupKey":"{}:{alertname=\"KubePodCrashLooping\", namespace=\"shop\"}","truncatedAlerts":0,"groupLabels":{"alertname":"KubePodCrashLooping","namespace":"shop"},"commonLabels":{"alertname":"KubePodCrashLooping","namespace":"shop","deployment":"checkout","severity":"critical"},"commonAnnotations":{"summary":"checkout is crash-looping in shop","description":"A checkout pod in shop restarted more than three times in the last ten minutes."},"externalURL":"http://alertmanager.local","alerts":[{"status":"$(STATUS)","labels":{"alertname":"KubePodCrashLooping","namespace":"shop","deployment":"checkout","severity":"critical"},"annotations":{"summary":"checkout is crash-looping in shop"},"startsAt":"'"$$now"'","endsAt":"0001-01-01T00:00:00Z","generatorURL":"http://prometheus.local/graph","fingerprint":"5f1c0a6e2b7d9c31"}]}' | \
	curl -sS --fail-with-body \
		-H "Authorization: Bearer $$(cat $(SECRETS)/oncall-alertmanager-webhook)" -H 'Content-Type: application/json' \
		--data-binary @- "http://api.kora.localhost:9880$$path" && echo && echo "Posted a $(STATUS) KubePodCrashLooping alert for shop/checkout."

# Deletes the cluster. The next make up reuses the files in .secrets.
down: tunnel-stop
	k3d cluster delete $(CLUSTER)

# Deletes the cluster and the generated files.
clean: down
	rm -rf $(SECRETS)
