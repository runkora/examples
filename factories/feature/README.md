# Feature factory

The feature factory is an example of a lights-off feature delivery loop in runkora. A person labels a feature request, and `spec-writer` opens the spec as a pull request. A person approves the spec by merging it. `captain` splits the spec into tasks and starts an `implementer` run for each one. Each task pull request goes through `reviewer`, CI and `verifier` until it is ready for a person to merge. When every task has merged, `captain` marks the feature done.

## How the factory works

1.  **Spec:** A person labels an issue `ready-to-spec`. `spec-writer` writes `specs/<issue>.md` with the tasks and acceptance criteria, and opens a pull request on `spec/<issue>`.
2.  **Approve:** A person reviews the spec and merges it.
3.  **Plan:** `captain` posts a checklist of the tasks on the issue and starts an `implementer` run for each task that is ready.
4.  **Build:** `implementer` builds its task with tests and opens a pull request on `feature/<issue>-<task>`.
5.  **Check:** `reviewer` reviews each push. When CI passes, `verifier` checks the acceptance criteria. Failed CI, reviews and verifications go back to `implementer`, which joins its open run.
6.  **Merge:** A person merges each task. `captain` ticks it off and starts the tasks that were waiting on it.

The implementer can push to the repository, and pushing also allows merging. Protect your default branch with a required approving review. The factory cannot approve its own pull requests.

## How the captain starts other agents

`captain` starts runs with the `runs:start` tool on the kora MCP server. The server checks the captain's own grant, and the captain's `scopes` allow it to start and read `implementer` runs and no other agent's. The checklist on the issue holds its progress. A merged task and a task labelled `needs-human` both wake it again.

## What each agent can reach

Each agent is set up with an example configuration:

| Agent | Model | kora | GitHub actions | Monthly budget |
| --- | --- | --- | --- | --- |
| `spec-writer` | `anthropic/claude-haiku-5-5` | None | `read`, `contents:write`, `pulls:write`, `issues:write` | $10 |
| `captain` | `anthropic/claude-haiku-5-5` | `agents:list`, `runs:start`, `runs:get`, `runs:list` on `implementer` | `read`, `issues:write` | $10 |
| `implementer` | `anthropic/claude-sonnet-5-5` | None | `read`, `contents:write`, `pulls:write` | $40 |
| `reviewer` | `anthropic/claude-haiku-5-5` | None | `read`, `pulls:write` | $20 |
| `verifier` | `anthropic/claude-haiku-5-5` | None | `read`, `pulls:write` | $20 |

## Adapt the agents to your repository

The prompts are general. Teach each agent about your repository: how to build and test it, the conventions you follow and what a good spec looks like for your team.

## Set it up

1.  Create a GitHub App with read and write access to contents, issues and pull requests, install it on your repository and generate a private key.
2.  In `factory/shared/github-connection.yaml`, set `app_id`, `installation_id` and `owner`.
3.  In every file in `factory/triggers/`, replace `example-org/example-repo` with your repository and `example-feature[bot]` with your App's bot user `<app-slug>[bot]`.
4.  On the quickstart, set `GITHUB_APP_PRIVATE_KEY_FILE` in `quickstart/.env`, uncomment `quickstart/providers/openrouter.yaml` and run:

    ```bash
    make credentials providers example EXAMPLE=factories/feature
    ```

    `make example` lists anything missing first.
5.  Run `make tunnel` and add a webhook to your repository with the URL and secret it prints. Select the issues, pull requests, pull request reviews and workflow runs events. See [Receive webhooks locally](../../quickstart/README.md#receive-webhooks-locally).
6.  Open an issue for a feature and add the label `ready-to-spec`.

Sign in as `feature-admin@local.runkora.io` to watch the runs. `feature-maintainer@local.runkora.io` can see the agents, triggers and runs.

## Run it on your own cluster

1.  Copy `platform/` and `factory/` into the repositories your GitOps tool reads.
2.  In `platform/tenants/feature.yaml`, replace the `oidc` block with your identity provider's client.
3.  In `platform/models/`, point each route at an `InferenceProvider` you registered.
4.  Create a `ClusterSecretStore` named `example-secret-store`. Store the App's private key under `feature-github-app` and the webhook secret under `feature-github-webhook`.

See [Declarative resources](https://github.com/runkora/kora/blob/main/docs/guides/declarative-resources.md) and [Create a trigger](https://github.com/runkora/kora/blob/main/docs/guides/create-a-trigger.md) for the resources the factory uses.
