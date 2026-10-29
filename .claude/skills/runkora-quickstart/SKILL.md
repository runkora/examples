---
name: runkora-quickstart
description: Install runkora on a local k3d cluster from this repository and run one of its examples. Use when asked to "set up runkora", "install the runkora examples", "demo runkora locally", "run the quickstart" or "try kora on my machine".
---

# runkora quickstart

The quickstart installs runkora on a local k3d cluster and applies one example. `quickstart/README.md` and each example's README hold the detail. Where this file and a README disagree, follow the README. Run every `make` command from the repository root.

## Rules

- **Secrets:** Never ask for, read or print an API key, private key or signing secret. The person writes them into `quickstart/.env`. To check a value is set, count the line, such as `grep -c '^OPENROUTER_API_KEY=.' quickstart/.env`.
- **sudo:** Never run `sudo`. Give the person the command to run in their own terminal.
- **Accounts:** Never create accounts, API keys, GitHub Apps or webhooks. Give the person the link and the settings, and wait for them.
- **Installs:** Ask before installing a tool.

## 1. Choose the demo

Ask what the person wants to see, and pick the example from the answer.

| They want to see | Example |
| --- | --- |
| One agent running under policy and a budget | `single-tenant` |
| Two teams, each with its own agents, access and budgets | `multi-tenant` |
| A factory of agents that finds, verifies and fixes bugs and opens a pull request | `factories/autofix` |
| Agents that triage alerts and sweep the cluster's costs | `factories/sre` |

If they are unsure, recommend `single-tenant`. It is the only example that needs nothing beyond a model provider.

## 2. Tell them what it needs

Tell the person what the example needs before installing anything.

| Example | Needs | Set-up section |
| --- | --- | --- |
| `single-tenant` | A model provider | |
| `multi-tenant` | OpenRouter, an Exa API key and a GitHub App on an organisation | `multi-tenant/README.md#prerequisites` |
| `factories/autofix` | OpenRouter, a GitHub App and a repository it is installed on | `factories/autofix/README.md#set-it-up` |
| `factories/sre` | OpenRouter, a GitHub App and a deploy repository holding `factories/sre/demo/` | `factories/sre/README.md#set-it-up` |

`multi-tenant`, `autofix` and `sre` route triggers with `typesafe/jev-1-14` on OpenRouter, and receive webhooks through `cloudflared`.

A GitHub App takes four steps. Wait for the person after each one.

1. **Create the App:** Open `https://github.com/settings/apps/new`, or `https://github.com/organizations/<org>/settings/apps/new` for an organisation. Clear **Webhook › Active**. The examples receive webhooks from the repository or organisation instead. `autofix` and `sre` need read and write access to contents, issues and pull requests. `multi-tenant` needs read access to contents and write access to pull requests.
2. **Install the App:** Install it on the repository or organisation and generate a private key. The person sets `GITHUB_APP_PRIVATE_KEY_FILE` in `quickstart/.env` to the `.pem` file's absolute path.
3. **Fill in the connection:** Ask for the App ID, the installation ID and the owner. None of them is secret. The installation ID is the number at the end of the installation's settings URL. Set `app_id`, `installation_id` and `owner` in the example's connection file:
   - `multi-tenant/engineering/shared/connections/github.yaml`
   - `factories/autofix/factory/shared/github-connection.yaml`
   - `factories/sre/factory/shared/github-connection.yaml`
4. **Point the triggers at the repository:** In `factory/triggers/`, replace the placeholder repository and bot with the person's repository and `<app-slug>[bot]`. The placeholders are `example-org/example-repo` and `example-autofix[bot]` in `autofix`, and `example-org/example-deploy` and `example-sre[bot]` in `sre`.

## 3. Check the prerequisites

Check each prerequisite in `quickstart/README.md#prerequisites` and report what is missing in one list.

| Check | Command | Passes when |
| --- | --- | --- |
| Docker resources | `docker info --format '{{.NCPU}} {{.MemTotal}}'` | At least 4 CPUs and 8 GiB |
| Ports | `lsof -nP -iTCP:9443 -iTCP:9880 -iTCP:5557 -sTCP:LISTEN` | No output |
| Tools | `command -v k3d kubectl helm mkcert openssl make` | Every tool found |

Webhook examples also need `cloudflared`, and Ollama needs `ollama`. On macOS, install the tools with `brew install k3d kubectl helm mkcert cloudflared`, and resize a Colima VM with `colima stop` and `colima start --cpu 4 --memory 8`.

## 4. Set up the model provider

Ask whether to use OpenRouter or Ollama. `quickstart/README.md#choose-a-model-provider` covers both.

- **OpenRouter** serves hosted models and bills per token. Models with a `:free` suffix cost nothing and are rate-limited.
- **Ollama** runs a model on the person's machine at no cost. Local models are weaker at tool calling. Offer it for `single-tenant` only. The other examples route triggers with a model on OpenRouter.

Run `cp quickstart/.env.example quickstart/.env` if `quickstart/.env` does not exist. Then:

- **OpenRouter:** The person creates a key at `https://openrouter.ai/keys` and sets `OPENROUTER_API_KEY` in `quickstart/.env`. Uncomment the resource in `quickstart/providers/openrouter.yaml`.
- **Ollama:** The person installs Ollama and runs `ollama pull gpt-oss:20b`. Uncomment the resource in `quickstart/providers/ollama.yaml`. In `single-tenant/tenant/agent.yaml`, set the model to family `openai` and name `gpt-oss-20b`.
- **`multi-tenant`** also needs `EXA_API_KEY` in `quickstart/.env`.

Run `make check-example EXAMPLE=<example>`. It lists what the example still needs without printing any value.

## 5. Install

`mkcert -install` asks for the system password the first time. Have the person run it in their own terminal before the install.

Run `make up EXAMPLE=<example> TUNNEL=no` for `single-tenant`, and `make up EXAMPLE=<example> TUNNEL=yes` for the others. Report each stage as it finishes, because the install takes several minutes.

`make up` runs these stages in order: `tools`, `cluster`, `namespaces`, `secrets`, `istio`, `spire`, `data`, `dex`, `eso`, `kora`, `credentials`, `providers`, `example`, `ask-tunnel`. `quickstart/README.md#install-stages` describes each one. When a stage fails, fix the cause and rerun that stage, such as `make kora`. Then run the stages after it in one command, such as `make credentials providers example EXAMPLE=<example>`. Do not rerun `make up` or run `make clean` to recover from one failed stage.

- `make status` and `kubectl --context k3d-kora-quickstart get pods -A` show the state of the cluster.
- When `make example` lists missing values, set them and run `make credentials example EXAMPLE=<example>`.
- When `make providers` finds no provider, uncomment the provider file and rerun `make providers`.

## 6. See it working

Open `https://local.runkora.io:9443` and sign in with the password `password`. `quickstart/README.md#users` lists every user.

- **`single-tenant`:** Sign in as `admin@local.runkora.io` and fire the `summarise-pr` trigger with a public pull request URL, such as `https://github.com/runkora/kora/pull/1`. `engineer@local.runkora.io` sees the same agent under the narrower `engineer` role.
- **`multi-tenant`:** Sign in as `admin@engineering.local.runkora.io`, then as `admin@sre.local.runkora.io`. Each admin sees only their own tenant. To run `code-reviewer`, add an organisation webhook for `kora-tenant-engineering/github-org` with the pull request event, then open a pull request.
- **`factories/autofix`:** Sign in as `admin@autofix.local.runkora.io`. Add a repository webhook with the issues, issue comment, pull request, pull request review and workflow run events, then open an issue for `bug-verifier` to check. `bug-hunter` also runs every morning at 09:00 UTC.
- **`factories/sre`:** Sign in as `admin@oncall.local.runkora.io`. Add a repository webhook with the issues, issue comment and pull request review events, then run `make alert` to raise the alert for the crash-looping `checkout` pod.

`make tunnel` prints each webhook's URL and the `kubectl` command that reads its signing secret. The person runs that command and enters both values in GitHub. A quick tunnel gets a new URL each time it starts, and the webhook needs the new URL after each `make tunnel`. `quickstart/README.md#receive-webhooks-locally` covers the tunnel.

`make tunnel-stop` stops the tunnel. `make down` deletes the cluster, and `make clean` also deletes `quickstart/.secrets/`.
