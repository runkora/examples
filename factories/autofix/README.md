# Autofix factory

The autofix factory is an example of a lights-off factory use case in runkora. Each agent has a role in the factory and handles its job when triggered. This example walks through an autonomous loop that trawls for bugs in a repository, verifies independently, proposes and implements a fix, goes through review and presents the human with a ready pull request.

## How the factory works

1.  **Hunt:** Every morning, `bug-hunter` reads the repository and files up to three issues for bugs, dead code and hard-to-maintain code. It labels each one `autofix:found`.
2.  **Verify:** `bug-verifier` checks every new issue against the code, whether the hunter or a person filed it. It labels the issue `verified` with a severity, or `duplicate`, `cannot-reproduce` or `needs-info`.
3.  **Fix:** `coder` picks up a verified issue, writes a failing test, fixes the code and opens a pull request that starts with `Fixes #<issue>`.
4.  **Review:** `code-reviewer` reviews each pull request the coder opens or updates, and ends its review with a verdict.
5.  **Respond:** Review comments, failed CI runs and comments from maintainers go back to `coder`, which works through them on the same pull request.
6.  **Stop:** The coder stops when the reviewer would approve and CI passes, and a person reviews and merges the pull request. If review or CI still fails after its third push, it labels the pull request `needs-human` and comments what remains.

The github permission for push also allows merging; protect your default branch with a required approving review. The factory cannot approve its own pull requests.

## What each agent can reach

Each agent is set up with an example configuration:

| Agent | Model | GitHub actions | Monthly budget |
| --- | --- | --- | --- |
| `bug-hunter` | `deepseek/deepseek-v4-1-flash` | `read`, `issues:write` | $10 |
| `bug-verifier` | `anthropic/claude-haiku-5-5` | `read`, `issues:write` | $10 |
| `coder` | `anthropic/claude-sonnet-5-5` | `read`, `contents:write`, `pulls:write` | $40 |
| `code-reviewer` | `anthropic/claude-haiku-5-5` | `read`, `pulls:write` | $20 |

The agents share a common sandbox environment, `build`, on the `kora-base` image. Change `sandboxImage` in `factory/shared/build-environment.yaml` to the image for your repository's language.

## Adapt the agents to your repository

The prompts in this example are general and work on any repository. Teach each agent about yours: how to build and test it, the conventions you follow and what you consider a bug.

## Choose the human gate

The factory ships with two gates between verifying and fixing:

*   **Gate A, `fix-verified.yaml`:** The coder starts when the verifier labels an issue `verified`. The factory can complete without a human in the loop.
*   **Gate B, `fix-assigned.yaml`:** The coder starts when a person assigns a verified issue to the factory's GitHub user. The factory pauses for a human in the loop.

Gate A is on in the example. To switch to gate B, remove `triggers/fix-verified.yaml` from `factory/kustomization.yaml` and uncomment the resource in `triggers/fix-assigned.yaml`. GitHub Apps cannot be assigned issues. Gate B needs a GitHub user for the factory instead.

## Set it up

1.  Create a GitHub App with read and write access to contents, issues and pull requests, install it on your organisation, and generate a private key.
2.  In `factory/shared/github-connection.yaml`, set `app_id`, `installation_id` and `owner`.
3.  In every file in `factory/triggers/`, replace `example-org/example-repo` with your repository and `example-autofix[bot]` with your App's bot user `<app-slug>[bot]`.
4.  On the quickstart, set `GITHUB_APP_PRIVATE_KEY_FILE` in `quickstart/.env`, uncomment `quickstart/providers/openrouter.yaml`, and run:

    ```bash
    make credentials providers example EXAMPLE=factories/autofix
    ```

    `make example` checks the key file, the owner and the placeholders first, and lists anything missing.
5.  Run `make tunnel` and add a webhook to your repository with the URL and secret it prints. Select the issues, issue comments, pull requests, pull request reviews and workflow runs events. See [Receive webhooks locally](../../quickstart/README.md#receive-webhooks-locally).

Sign in as `admin@autofix.local.runkora.io` to watch the factory's runs. `maintainer@autofix.local.runkora.io` can see the agents, triggers and runs.

## Run it on your own cluster

1.  Copy `platform/` and `factory/` into the repositories your GitOps tool reads.
2.  In `platform/tenants/autofix.yaml`, replace the `oidc` block with the client your identity provider gives you.
3.  In `platform/models/`, point each route at an `InferenceProvider` you registered.
4.  Create a `ClusterSecretStore` named `example-secret-store` that points at your secret manager. Store the App's private key under `autofix-github-app` and the webhook signing secret under `autofix-github-webhook`.

See [Declarative resources](https://github.com/runkora/kora/blob/main/docs/guides/declarative-resources.md) for every kind and field, and [Create a trigger](https://github.com/runkora/kora/blob/main/docs/guides/create-a-trigger.md) for routing and joining runs.
