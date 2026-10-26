# Autofix factory

The autofix factory finds problems in one GitHub repository and fixes them. Four agents work in turn, and each one holds only the GitHub access its stage needs. A person receives a pull request that the reviewer would approve and that passes CI, or one labelled `needs-human` with a summary of what remains.

## How the factory works

1.  **Hunt:** Every morning, `bug-hunter` reads the repository and files up to three issues for bugs, dead code and hard-to-maintain code. It labels each one `autofix:found`.
2.  **Verify:** `bug-verifier` checks every new issue against the code, from the hunter or from a person. It labels the issue `verified` with a severity, or `duplicate`, `cannot-reproduce` or `needs-info`.
3.  **Fix:** `coder` fixes a verified issue with a failing test first, and opens a pull request that starts with `Fixes #<issue>`.
4.  **Review:** `code-reviewer` reviews each pull request the coder opens or updates, and ends its review with a verdict.
5.  **Respond:** The reviewer's review, a failed CI run and a person's comment each go back to `coder`. kora joins the event to the coder's open run for that pull request when there is one, and otherwise starts a new run.
6.  **Stop:** The coder stops when the reviewer would approve and CI passes. After its third push with review or CI still failing, it labels the pull request `needs-human` and comments what remains. The factory never merges.

## Files

*   **`platform/`:** The platform team's repository: the tenant `autofix` and the models.
*   **`factory/`:** The factory's repository, applied to `kora-tenant-autofix`.
    *   `shared/`: The GitHub App connection, the GitHub webhook source, the `build` environment and the `maintainer` role.
    *   `agents/`: `bug-hunter`, `bug-verifier`, `coder` and `code-reviewer`.
    *   `triggers/`: One file per stage.

Each agent runs on the model that suits its stage:

| Agent | Model | GitHub actions |
| --- | --- | --- |
| `bug-hunter` | `deepseek/deepseek-v4-1-flash` | `read`, `issues:write` |
| `bug-verifier` | `anthropic/claude-haiku-5-5` | `read`, `issues:write` |
| `coder` | `anthropic/claude-sonnet-5-5` | `read`, `contents:write`, `pulls:write` |
| `code-reviewer` | `anthropic/claude-haiku-5-5` | `read`, `pulls:write` |

The routed triggers decide whether an event joins an open run with the decision model `typesafe/jev-1-14`.

## Choose the human gate

The factory ships with two gates between verifying and fixing:

*   **Gate A, `fix-verified.yaml`:** The coder starts when the verifier labels an issue `verified`. The factory runs on its own.
*   **Gate B, `fix-assigned.yaml`:** The coder starts when a person assigns a verified issue to the factory's GitHub user. A person decides which issues get fixed.

Gate A is on. To switch to gate B, remove `triggers/fix-verified.yaml` from `factory/kustomization.yaml` and uncomment the resource in `triggers/fix-assigned.yaml`. GitHub Apps cannot be assigned issues. Gate B needs a GitHub user for the factory instead.

## Set it up

1.  Create a GitHub App with read and write access to contents, issues and pull requests, install it on your organisation, and generate a private key.
2.  In `factory/shared/github-connection.yaml`, set `app_id`, `installation_id` and `owner`.
3.  In every file in `factory/triggers/`, replace `example-org/example-repo` with your repository and `example-autofix[bot]` with your App's bot user `<app-slug>[bot]`.
4.  On the quickstart, set `GITHUB_APP_PRIVATE_KEY_FILE` in `quickstart/.env`, uncomment `quickstart/providers/openrouter.yaml`, and run:

    ```bash
    make credentials providers example EXAMPLE=factories/autofix
    ```

    `make example` checks steps 1 to 3 first and lists anything missing.
5.  Run `make tunnel` and add a webhook to your repository with the URL and secret it prints. Select the issues, issue comments, pull requests, pull request reviews and workflow runs events. See [Receive webhooks locally](../../quickstart/README.md#receive-webhooks-locally).

Sign in as `admin@autofix.local.runkora.io` to watch the factory's runs. `maintainer@autofix.local.runkora.io` can see the agents, triggers and runs.

## Run it on your own cluster

1.  Copy `platform/` and `factory/` into the repositories your GitOps tool reads.
2.  In `platform/tenants/autofix.yaml`, replace the `oidc` block with the client your identity provider gives you.
3.  In `platform/models/`, point each route at an `InferenceProvider` you registered.
4.  Create a `ClusterSecretStore` named `example-secret-store` that points at your secret manager. Store the App's private key under `autofix-github-app` and the webhook signing secret under `autofix-github-webhook`.

See [Declarative resources](https://github.com/runkora/kora/blob/main/docs/guides/declarative-resources.md) for every kind and field, and [Create a trigger](https://github.com/runkora/kora/blob/main/docs/guides/create-a-trigger.md) for routing and joining runs.
