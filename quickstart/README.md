# Quickstart: runkora on k3d

The quickstart installs runkora on a local k3d cluster. It installs Istio, SPIRE, Postgres, Redis, Dex and External Secrets Operator, and the two kora charts from the published release.

## Prerequisites

*   Docker Desktop or Colima with at least 4 CPUs and 8 GiB of memory allocated to the VM.
*   `k3d`, `kubectl`, `helm`, `mkcert`, `openssl` and `make`. On macOS, install them with `brew install k3d kubectl helm mkcert`.
*   Free ports 9443, 9880 and 5557 on your machine.
*   An OpenRouter account, or Ollama on your machine.

## Files

*   `Makefile`: The install steps that you run from the repository root.
*   `.env.example`: A template for your API keys that you copy to `.env`.
*   `k3d.yaml`: The local cluster.
*   `values/`: Settings for Istio, SPIRE and kora.
*   `manifests/`: Postgres, Redis, Dex and the secret store.
*   `providers/`: The model providers, OpenRouter and Ollama.
*   `../versions.mk`: The versions the quickstart installs.

## Install kora

1.  **Choose a model provider:** Set up OpenRouter or Ollama as described in [Choose a model provider](#choose-a-model-provider).
2.  **Run the install:** Run `make up`. Expect the install to take several minutes.
3.  **Choose an example:** At the end, `make up` asks which example to apply:
    *   **[`single-tenant`](../single-tenant):** One tenant with one agent that runs on the model provider alone.
    *   **[`multi-tenant`](../multi-tenant):** Two tenants, engineering and SRE, with four use cases. It also needs an Exa API key and a GitHub App.
    *   **`none`:** Installs kora with no tenants. You can apply an example later with `make example`.

    Set `EXAMPLE` to skip the question, such as `make up EXAMPLE=multi-tenant`.
4.  **Sign in:** Open `https://local.runkora.io:9443` and sign in with a user from [Users](#users) for the example you applied.

`*.local.runkora.io` is a public DNS record that resolves to `127.0.0.1`. It needs no local DNS setup.

## Choose a model provider

Each example declares four models in its `platform/models/`:

*   `anthropic/claude-haiku-5-5` routes to OpenRouter and is the default model for the agents.
*   `deepseek/deepseek-v4-1-flash` and `openai/gpt-6-luna` route to OpenRouter.
*   `openai/gpt-oss-20b` routes to Ollama.

### OpenRouter

OpenRouter serves hosted models that work well with kora's agent harnesses. It bills per token. Models with a `:free` suffix cost nothing and are rate-limited.

1.  Create an account at [openrouter.ai](https://openrouter.ai) and create an API key at [openrouter.ai/keys](https://openrouter.ai/keys).
2.  Copy `.env.example` to `.env` and set `OPENROUTER_API_KEY`. Write the value without quotes.

    ```bash
    cp quickstart/.env.example quickstart/.env
    ```

3.  Uncomment the resource in `quickstart/providers/openrouter.yaml`.

### Ollama

Ollama runs a model on your machine with no account. Local models are smaller than hosted ones and weaker at tool calling. Expect loops, invented tool calls and ignored instructions. Choose a model whose publisher lists tool calling, such as those under Ollama's [tools filter](https://ollama.com/search?c=tools). A local model costs nothing and no per-run budget limits it. The idle timeout and the loop guardrails end its runs.

1.  Install Ollama and pull the model:

    ```bash
    ollama pull gpt-oss:20b
    ```

2.  Uncomment the resource in `quickstart/providers/ollama.yaml`.
3.  Set each agent's `model` to family `openai` and name `gpt-oss-20b`. The agents are the `agent.yaml` files in the example's tenant folders.

## Install stages

Each stage is a `make` target. Run one on its own to watch what it installs.

1.  **`make cluster`:** Creates the `kora-quickstart` cluster from `k3d.yaml` and raises the Docker VM's inotify limit for kora's file watchers.
2.  **`make namespaces`:** Creates `kora-data`, `dex`, `kora-credentials` and `kora-system`. The `kora-system` labels turn on Istio sidecar injection and the restricted Pod Security level.
3.  **`make secrets`:** Generates the keys, passwords and the `*.local.runkora.io` certificate into `.secrets/`, then stores them in the cluster. `mkcert -install` adds the local CA to your system trust store and asks for your password the first time.
4.  **`make istio`:** Installs Istio in sidecar mode with the CNI plugin.
5.  **`make spire`:** Installs SPIRE. SPIRE issues a SPIFFE identity to every kora workload and agent.
6.  **`make data`:** Starts Postgres and Redis in `kora-data`.
7.  **`make dex`:** Starts Dex and glauth in `dex`. Dex is the sign-in provider for every example's tenants.
8.  **`make eso`:** Installs External Secrets Operator and the `example-secret-store` store in `manifests/credentials/store.yaml`. The store reads from `kora-credentials`.
9.  **`make kora`:** Installs the `kora-crds` and `kora` charts. The `kora` chart's pre-install hook creates the database schema.
10.  **`make credentials`:** Creates a Secret for each value set in `.env`, and generates a webhook signing secret per tenant and provider. It prints each variable and Secret name.
11.  **`make providers`:** Applies the providers you uncommented in `providers/`.
12.  **`make example`:** Asks which example to run, applies its platform repository, waits for the operator to create each tenant's namespace, then applies its tenant repositories.
13.  **`make ask-tunnel`:** Asks whether to start a webhook tunnel. See [Receive webhooks locally](#receive-webhooks-locally).

Inspect the cluster between stages with `kubectl --context k3d-kora-quickstart get pods -A`.

## Users

Every user signs in with the password `password`. kora routes each person to a tenant by the domain of their email. A user can sign in once the example that declares their tenant is applied.

*   **`single-tenant`:**
    *   `admin@local.runkora.io`: Groups `platform-admin` and `engineer`.
    *   `engineer@local.runkora.io`: Groups `engineer` and `kora-viewer`.
*   **`multi-tenant`:**
    *   `admin@engineering.local.runkora.io`: Tenant `engineering`, group `platform-admin`.
    *   `dev@engineering.local.runkora.io`: Tenant `engineering`, groups `reviewer` and `kora-viewer`.
    *   `admin@sre.local.runkora.io`: Tenant `sre`, group `platform-admin`.
    *   `oncall@sre.local.runkora.io`: Tenant `sre`, groups `sre` and `kora-viewer`.

The users and their groups live in `manifests/dex/glauth.yaml`. kora reads a person's roles from the `groups` claim in their ID token. `platform-admin` holds every scope in kora, and `kora-viewer` reads everything in the tenant. Both are built-in roles that kora maps from the group name. Each example grants the other groups their scopes with `PolicyRole` resources.

## Run another example

Run `make example` and choose another example. The examples declare different tenants and can run side by side. To apply one by hand, apply its `platform/` folder first, then each tenant repository once the tenant namespaces exist.

## Receive webhooks locally

A webhook trigger fires only when the provider can reach the cluster. A tunnel gives the cluster's API a public URL. Start one by answering yes to the tunnel question at the end of `make up`, or by running `make up TUNNEL=yes`. `make tunnel` starts one at any time.

1.  Install `cloudflared`, such as with `brew install cloudflared` on macOS.
2.  Run `make tunnel`. It starts a Cloudflare quick tunnel and prints each trigger source's webhook URL and the command that prints its signing secret.
3.  In the provider, such as a GitHub repository's webhook settings, set the URL and the secret. Select the events the example's triggers use.
4.  Stop the tunnel with `make tunnel-stop` or `make down`.

The tunnel makes the console and the API reachable from the internet while it runs. The webhook path accepts only events signed with the source's secret, and the console and the API still need a sign-in.

A quick tunnel gets a new URL each time it starts. Update the provider's webhook URL after each `make tunnel`. For a URL that stays the same, create a [named Cloudflare tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/) or use ngrok with a reserved domain. Point either one at `https://localhost:9443` with the host header `api.local.runkora.io`.

## How an agent reaches a model

An agent never references a provider. Each link in the chain is a separate resource, owned by a separate layer:

1.  **Agent:** An example's `Agent` sets its `model` field to a model such as `anthropic/claude-haiku-5-5`.
2.  **Model:** The example's `platform/models/` declares each model as a `VirtualModel` in `kora-system` that every tenant can use. Each route references a provider: `compatible:openrouter` or `compatible:ollama`.
3.  **Provider:** `providers/openrouter.yaml` and `providers/ollama.yaml` in the quickstart register the providers. They are for the quickstart only: the Ollama provider reaches your machine at `host.k3d.internal`, and the OpenRouter key comes from `.env`.

On your own cluster, keep the agents and the tenants, and point each model's route at a provider you registered there.

## Change a model provider

1.  Edit a provider file. If the provider needs a key, set it in `.env`.
2.  Run `make credentials providers`. kora applies the change without a restart.
3.  Run `kubectl --context k3d-kora-quickstart -n kora-system get inferenceproviders` to check the provider.

## Use your own sign-in provider

Replace `issuerURL` and `clientID` in a tenant under the example's `platform/tenants/` with the values from your provider, set `emailDomains` to your domain, and run `make example` again. The provider must allow the redirect URI `https://local.runkora.io:9443/auth/callback`.

## Check and remove the install

*   `make status` lists the Helm releases, the tenants, the providers and models, every resource the examples declared, and every pod that is not running.
*   `make down` deletes the cluster. The files in `.secrets/` stay for the next `make up`.
*   `make clean` deletes the cluster and `.secrets/`, and keeps your `.env`.

## Next steps

*   [Declarative resources](https://github.com/runkora/kora/blob/main/docs/guides/declarative-resources.md)
*   [Register an inference provider](https://github.com/runkora/kora/blob/main/docs/guides/register-inference-provider.md)
*   [Register an MCP server](https://github.com/runkora/kora/blob/main/docs/guides/register-mcp-server.md)
*   [Register a connection](https://github.com/runkora/kora/blob/main/docs/guides/register-connection.md)
*   [Deploying runkora](https://github.com/runkora/kora/blob/main/docs/guides/deployment.md)
