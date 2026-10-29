---
name: runkora-quickstart
description: Install runkora on a local k3d cluster from this repository and run one of its examples, from the prerequisites to a signed-in console with a run to watch. Use when asked to "set up runkora", "install the runkora examples", "demo runkora locally", "run the quickstart" or "try kora on my machine".
---

# runkora quickstart

This skill takes a person from a fresh clone of this repository to a running runkora demo on a local k3d cluster. `quickstart/README.md` and each example's README are the source of truth. Each step below cites the README section that holds the detail. Read that section before you act on the step. Paths are relative to the repository root, and every `make` command runs from the root.

## Rules

Apply these rules at every step:

*   **Secrets:** Do **not** ask for, print or echo an API key, a private key or a webhook signing secret. The person writes each value into `quickstart/.env` themselves. Do not read `quickstart/.env`, `quickstart/.secrets/` or a `.pem` file. Check that a value is set with `grep -c '^OPENROUTER_API_KEY=.' quickstart/.env` and report only the count.
*   **sudo:** Do not run `sudo`. When a step needs it, give the person the command to run in their own terminal and wait for them.
*   **Accounts:** Do not create accounts, API keys, GitHub Apps or webhooks for the person. Give the link and the exact settings, and wait for the person to confirm each one. Ask before you push to any repository.
*   **Installs:** Ask before you install a tool. List each tool and the install command first.
*   **README first:** If this file and a README disagree, follow the README.

## 1. Choose the demo

Ask the person what they want to see demoed. Offer these outcomes and map the answer to an example:

*   **One agent under policy and a budget:** `single-tenant` declares one tenant with an agent that summarises pull requests.
*   **Teams kept apart:** `multi-tenant` gives an engineering team and an SRE team separate tenants with their own agents, access and budgets.
*   **A bug-fixing factory:** `factories/autofix` runs four agents that find, verify and fix problems in a GitHub repository and hand a person the pull request.
*   **Alert triage and cost sweeps:** `factories/sre` runs agents that triage alerts in the cluster, sweep its costs with OpenCost and propose fixes as pull requests.
*   **Not sure:** Recommend `single-tenant`. It has the fewest steps and needs only a model provider.

## 2. State what the demo needs

Before you install anything, tell the person what the example needs beyond the base install:

*   **`single-tenant`:** A model provider.
*   **`multi-tenant`:** OpenRouter, an Exa API key and a GitHub App installed on an organisation. See `multi-tenant/README.md#prerequisites`.
*   **`factories/autofix`:** OpenRouter, a GitHub App and a repository the App is installed on. See `factories/autofix/README.md#set-it-up`.
*   **`factories/sre`:** OpenRouter, a GitHub App and a deploy repository that holds the contents of `factories/sre/demo/`. See `factories/sre/README.md#set-it-up`.

The routed triggers in `multi-tenant`, `autofix` and `sre` pick an agent with the decision model `typesafe/jev-1-14` on OpenRouter. These three examples also need `cloudflared` for the webhook tunnel.

For an example with a GitHub App, give the person these web steps and wait after each one:

1.  **Create the App:** Open `https://github.com/settings/apps/new`, or `https://github.com/organizations/<org>/settings/apps/new` for an organisation. The `autofix` and `sre` factories need read and write access to contents, issues and pull requests. In `multi-tenant`, `code-reviewer` reads the repository and posts reviews with `pulls:write`.
2.  **Install the App:** Install it on the organisation or the repository, and generate a private key. GitHub downloads a `.pem` file. The person sets `GITHUB_APP_PRIVATE_KEY_FILE` to its absolute path in step 4.
3.  **Fill in the connection:** Ask for the App ID, the installation ID and the owner. None of them is a secret. The installation ID is the number at the end of the installation's settings URL. Set `app_id`, `installation_id` and `owner` in the example's connection file:
    *   `multi-tenant/engineering/shared/connections/github.yaml`
    *   `factories/autofix/factory/shared/github-connection.yaml`
    *   `factories/sre/factory/shared/github-connection.yaml`
4.  **Point the triggers at the repository:** In every file in the factory's `factory/triggers/`, replace the repository and the bot user with the person's repository and `<app-slug>[bot]`. `autofix` uses `example-org/example-repo` and `example-autofix[bot]`, and `sre` uses `example-org/example-deploy` and `example-sre[bot]`.

## 3. Check the prerequisites

See `quickstart/README.md#prerequisites`. Run these checks and report one list of what is present and what is missing:

*   **Docker:** Run `docker info --format '{{.NCPU}} {{.MemTotal}}'`. The Docker Desktop or Colima VM needs at least 4 CPUs and 8 GiB of memory. On Colima, the person resizes the VM with `colima stop` and `colima start --cpu 4 --memory 8`.
*   **Ports:** Run `lsof -nP -iTCP:9443 -iTCP:9880 -iTCP:5557 -sTCP:LISTEN`. Any line of output is a process that holds a port the cluster needs.
*   **Tools:** Run `command -v` for `k3d`, `kubectl`, `helm`, `mkcert`, `openssl` and `make`. Add `cloudflared` for an example that needs the tunnel, and `ollama` if the person chooses Ollama.

On macOS, install the missing tools with `brew install k3d kubectl helm mkcert`, and `cloudflared` with `brew install cloudflared`. On another OS, point the person at each tool's install docs.

## 4. Set up the model provider

See `quickstart/README.md#choose-a-model-provider`. Ask whether to use OpenRouter or Ollama, and state the trade-off:

*   **OpenRouter:** OpenRouter serves hosted models that work well with kora's agent harnesses and bills per token. Models with a `:free` suffix cost nothing and are rate-limited.
*   **Ollama:** Ollama runs a model on the person's machine with no account and no cost. Local models are weaker at tool calling, and the person should expect loops, invented tool calls and ignored instructions. Offer Ollama for `single-tenant` only.

Set up the provider:

1.  Run `cp quickstart/.env.example quickstart/.env` if `quickstart/.env` does not exist.
2.  For OpenRouter, the person creates a key at `https://openrouter.ai/keys` and writes it after `OPENROUTER_API_KEY=` in `quickstart/.env` without quotes. Uncomment the resource in `quickstart/providers/openrouter.yaml`: remove the leading `# ` from every line from `# apiVersion:` to the end of the file.
3.  For Ollama, the person installs Ollama and runs `ollama pull gpt-oss:20b`. Uncomment the resource in `quickstart/providers/ollama.yaml` the same way. In `single-tenant/tenant/agent.yaml`, set `model` to family `openai` and name `gpt-oss-20b`.
4.  For `multi-tenant`, the person writes `EXA_API_KEY` in `quickstart/.env`. For an example with a GitHub App, the person writes `GITHUB_APP_PRIVATE_KEY_FILE`.
5.  Run `make check-example EXAMPLE=<example>`. It lists anything the example still needs and prints no values.

## 5. Install

See `quickstart/README.md#install-kora` and `quickstart/README.md#install-stages`.

1.  **Trust the local CA:** The `mkcert -install` in `make secrets` asks for the system password the first time. Warn the person, and ask them to run `mkcert -install` in their own terminal before the install.
2.  **Run the install:** Run `make up EXAMPLE=<example> TUNNEL=no` for `single-tenant` and `make up EXAMPLE=<example> TUNNEL=yes` for the others. The install takes several minutes. Run it in the background or with a long timeout, and report each stage as it finishes.
3.  **Handle a failure:** Read the error and find the stage that failed. The stages run in this order: `cluster`, `namespaces`, `secrets`, `istio`, `spire`, `data`, `dex`, `eso`, `kora`, `credentials`, `providers`, `example`, `ask-tunnel`. Fix the cause and rerun the failed stage on its own, such as `make kora`. When it passes, run the stages after it in one command, such as `make credentials providers example EXAMPLE=<example>`. Do not rerun `make up` or run `make clean` to recover from one failed stage.
    *   Inspect the cluster with `make status` and `kubectl --context k3d-kora-quickstart get pods -A`.
    *   If `make example` lists missing values, fix them and run `make credentials example EXAMPLE=<example>`.
    *   If `make providers` reports that no model provider is enabled, uncomment the provider file and run `make providers`.

## 6. See it working

Open `https://local.runkora.io:9443` and sign in with the user for the example and the password `password`. See `quickstart/README.md#users` for every user and group.

*   **`single-tenant`:** Sign in as `admin@local.runkora.io`. Open the `summarise-pr` trigger and fire it with a public pull request URL, such as `https://github.com/runkora/kora/pull/1`. The `pr-summariser` run appears in the console. `engineer@local.runkora.io` sees the same agent with the narrower `engineer` role.
*   **`multi-tenant`:** Sign in as `admin@engineering.local.runkora.io`, then as `admin@sre.local.runkora.io`. Each admin sees only their own tenant. To see `code-reviewer` run, add an organisation webhook with the URL and secret that `make tunnel` prints for `kora-tenant-engineering/github-org`, select the pull request event, and open a pull request.
*   **`factories/autofix`:** Sign in as `admin@autofix.local.runkora.io`. The person adds a repository webhook with the URL and secret that `make tunnel` prints, and selects the issues, issue comments, pull requests, pull request reviews and workflow runs events. `bug-hunter` runs every morning at 09:00 UTC. To start the loop sooner, open an issue in the repository for `bug-verifier` to check. See `factories/autofix/README.md#how-the-factory-works`.
*   **`factories/sre`:** Sign in as `admin@oncall.local.runkora.io`. The person adds a repository webhook with the URL and secret that `make tunnel` prints, and selects the issues, issue comments and pull request reviews events. Run `make alert` to post the alert for the crash-looping `checkout` pod. See `factories/sre/README.md#fire-an-alert-on-the-quickstart` to resolve it.

`make tunnel` prints a `kubectl` command for each source's signing secret. Do not run that command yourself. The person runs it in their own terminal and pastes the value into the GitHub webhook settings. A quick tunnel gets a new URL each time it starts, and the person updates the webhook after each `make tunnel`. See `quickstart/README.md#receive-webhooks-locally`.

When the person is done, `make tunnel-stop` stops the tunnel, `make down` deletes the cluster and `make clean` also deletes `quickstart/.secrets/`.
