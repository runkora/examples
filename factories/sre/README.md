# SRE factory

The SRE factory is an example of a lights-off incident response use case in runkora. Each agent has a role in the factory and handles its job when triggered. This example walks through an autonomous loop that picks up a firing alert, investigates the cluster read-only, opens an incident issue with the likely cause, proposes a fix to the deploy repository and closes the incident with a summary once the alert resolves. Once a week, a cost sweeper reviews what the cluster spends with OpenCost and recommends rightsizing changes through the same loop.

## How the factory works

1.  **Triage:** An alert fires in Alertmanager. `incident-triage` picks it up, and alerts from the same group join the same incident. It inspects the pods, logs, events and rollouts in the alert's namespace with `kubectl`.
2.  **Record:** `incident-triage` opens an issue labelled `incident` in the deploy repository with the likely cause, the evidence and the impact. When a change to the repository fixes the cause, it adds the label `remediate`.
3.  **Fix:** `remediator` picks up the `remediate` label, makes the change and opens a pull request that starts with `Fixes #<issue>`.
4.  **Respond:** Comments on the incident issue go to `incident-triage`, and reviews and comments on the pull request go to `remediator`.
5.  **Resolve:** A person reviews and merges the fix. When the alert resolves, `incident-triage` comments a summary on the issue and closes it.
6.  **Sweep:** Every Monday, `cost-sweeper` reviews the cluster's costs and efficiency through OpenCost's MCP server and opens an issue labelled `cost` with each recommendation and its saving. When a change to a manifest in the repository applies, it adds the label `remediate`, and `remediator` opens the pull request.

The remediator can push to the deploy repository, which also lets it merge. Protect your default branch with a required approving review. The factory cannot approve its own pull requests.

## What each agent can reach

Each agent is set up with an example configuration:

| Agent | Model | Cluster access | GitHub actions | Monthly budget |
| --- | --- | --- | --- | --- |
| `incident-triage` | `anthropic/claude-haiku-5-5` | `workloads:read`, `config:read`, `networking:read`, `cluster:read` | `read`, `issues:write` | $30 |
| `remediator` | `anthropic/claude-haiku-5-5` | None | `read`, `contents:write`, `pulls:write`, `issues:write` | $20 |
| `cost-sweeper` | `anthropic/claude-haiku-5-5` | OpenCost `get_allocation_costs`, `get_asset_costs`, `get_efficiency` | `read`, `issues:write` | $10 |

The cluster connection in `factory/shared/cluster-connection.yaml` uses a ServiceAccount token, and the ClusterRole in `platform/cluster-access.yaml` limits it to reading. It cannot read Secrets.

OpenCost serves its MCP server in the `opencost` namespace. `factory/shared/opencost-mcp.yaml` registers it with a relay in the tenant namespace, which the tool gateway can reach.

## Adapt the agents to your cluster

The prompts in this example are general and work on any cluster. Teach each agent about yours: your runbooks, how your services depend on each other and where the deploy repository keeps each workload's manifests.

## Set it up

1.  Create a GitHub repository for your deploy manifests and incidents, and push the contents of `demo/` to it.
2.  Create a GitHub App with read and write access to contents, issues and pull requests, install it on the repository, and generate a private key.
3.  In `factory/shared/github-connection.yaml`, set `app_id`, `installation_id` and `owner`.
4.  In every file in `factory/triggers/`, replace `example-org/example-deploy` with your repository and `example-sre[bot]` with your App's bot user `<app-slug>[bot]`.
5.  On the quickstart, set `GITHUB_APP_PRIVATE_KEY_FILE` in `quickstart/.env`, uncomment `quickstart/providers/openrouter.yaml`, and run:

    ```bash
    make credentials providers example EXAMPLE=factories/sre
    ```

    `make example` checks the key file, the owner and the placeholders first, and lists anything missing. It installs OpenCost, sets the cluster connection's `caCert` to the quickstart's CA and deploys the broken `checkout` service from `demo/` to the `shop` namespace.
6.  Run `make tunnel` and add a webhook to your repository with the URL and secret it prints. Select the issues, issue comments and pull request reviews events. See [Receive webhooks locally](../../quickstart/README.md#receive-webhooks-locally).

Sign in as `admin@oncall.local.runkora.io` to watch the factory's runs. `sre@oncall.local.runkora.io` can see the agents, triggers and runs.

## Fire an alert on the quickstart

The quickstart runs no Prometheus or Alertmanager. `make alert` posts the alert Alertmanager would send for the crash-looping `checkout` pod:

```bash
make alert
```

The quickstart does not sync the deploy repository to the cluster. Once you merge the fix, apply your repository to the cluster and resolve the alert:

```bash
kubectl --context k3d-kora-quickstart apply -k <your clone of the deploy repository>
make alert STATUS=resolved
```

## Run it on your own cluster

1.  Copy `platform/` and `factory/` into the repositories your GitOps tool reads.
2.  In `platform/tenants/oncall.yaml`, replace the `oidc` block with the client your identity provider gives you.
3.  In `platform/models/`, point each route at an `InferenceProvider` you registered.
4.  In `factory/shared/cluster-connection.yaml`, set `baseHost` to your API server's hostname and `caCert` to its CA certificate.
5.  Create a `ClusterSecretStore` named `example-secret-store` that points at your secret manager. Store the App's private key under `oncall-github-app`, the GitHub webhook secret under `oncall-github-webhook` and the Alertmanager bearer token under `oncall-alertmanager-webhook`.
6.  Add a webhook receiver to Alertmanager with the alertmanager source's URL and the bearer token.
7.  Install OpenCost with `opencost.mcp.enabled: true`. `quickstart/values/opencost.yaml` shows the values for a cluster without Prometheus.

See [Declarative resources](https://github.com/runkora/kora/blob/main/docs/guides/declarative-resources.md) for every kind and field, [Register a connection](https://github.com/runkora/kora/blob/main/docs/guides/register-connection.md) for the cluster connection, and [Create a trigger](https://github.com/runkora/kora/blob/main/docs/guides/create-a-trigger.md) for routing and joining runs.
