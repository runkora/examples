# SRE factory

The SRE factory is an example of a lights-off incident response loop in runkora. When an alert fires, `incident-triage` investigates the cluster and records the incident in GitHub, and `remediator` opens a pull request with the fix. A person reviews and merges it. When the alert resolves, `incident-triage` writes up the incident and closes it. Once a week, `cost-sweeper` reviews what the cluster costs and files an issue with savings, which `remediator` turns into a pull request when a manifest change applies.

## How the factory works

1.  **Triage:** An alert fires and `incident-triage` starts. Alerts from the same group join the same run. It reads the pods, logs, events and rollouts in the alert's namespace with `kubectl`.
2.  **Record:** It opens an `incident` issue in the deploy repository with the cause, the evidence and the impact. When a manifest change fixes the cause, it adds the `remediate` label.
3.  **Fix:** `remediator` makes the change and opens a pull request. The incident stays open until its alert resolves.
4.  **Respond:** Comments on the incident go to `incident-triage`. Reviews and comments on the pull request go to `remediator`.
5.  **Resolve:** A person merges the fix. When the alert resolves, `incident-triage` writes a summary and closes the incident.
6.  **Sweep:** Every Monday, `cost-sweeper` reads the cluster's costs from OpenCost and opens a `cost` issue with savings. It adds `remediate` when a manifest change applies.

The remediator can push to the deploy repository, and pushing also allows merging. Protect your default branch with a required approving review. The factory cannot approve its own pull requests.

## What each agent can reach

Each agent is set up with an example configuration:

| Agent | Model | Cluster access | GitHub actions | Monthly budget |
| --- | --- | --- | --- | --- |
| `incident-triage` | `anthropic/claude-haiku-5-5` | `workloads:read`, `config:read`, `networking:read`, `cluster:read` | `read`, `issues:write` | $30 |
| `remediator` | `anthropic/claude-haiku-5-5` | None | `read`, `contents:write`, `pulls:write`, `issues:write` | $20 |
| `cost-sweeper` | `anthropic/claude-haiku-5-5` | OpenCost `get_allocation_costs`, `get_asset_costs`, `get_efficiency` | `read`, `issues:write` | $10 |

`incident-triage` reads the cluster through a kubernetes connection with a read-only ServiceAccount. It cannot read Secrets. `cost-sweeper` calls OpenCost's MCP server through a relay in the tenant namespace.

## Adapt the agents to your cluster

The prompts are general. Teach each agent about your cluster: your runbooks, how your services depend on each other and where the deploy repository keeps each workload.

## Set it up

1.  Create a GitHub repository for your deploy manifests and incidents, and push `demo/` to it.
2.  Create a GitHub App with read and write access to contents, issues and pull requests, install it on the repository and generate a private key.
3.  In `factory/shared/github-connection.yaml`, set `app_id`, `installation_id` and `owner`.
4.  In every file in `factory/triggers/`, replace `example-org/example-deploy` with your repository and `example-sre[bot]` with your App's bot user `<app-slug>[bot]`.
5.  On the quickstart, set `GITHUB_APP_PRIVATE_KEY_FILE` in `quickstart/.env`, uncomment `quickstart/providers/openrouter.yaml` and run:

    ```bash
    make credentials providers example EXAMPLE=factories/sre
    ```

    `make example` lists anything missing first. It installs OpenCost, connects the factory to the quickstart's API server and deploys the broken `checkout` service from `demo/`.
6.  Run `make tunnel` and add a webhook to your repository with the URL and secret it prints. Select the issues, issue comments and pull request reviews events. See [Receive webhooks locally](../../quickstart/README.md#receive-webhooks-locally).

Sign in as `oncall-admin@local.runkora.io` to watch the runs. `oncall-sre@local.runkora.io` can see the agents, triggers and runs.

## Fire an alert on the quickstart

The quickstart has no Alertmanager. `make alert` sends the alert it would send for the crash-looping `checkout` pod:

```bash
make alert
```

Nothing deploys the repository to the quickstart. After you merge the fix, apply it yourself and resolve the alert:

```bash
kubectl --context k3d-kora-quickstart apply -k <your clone of the deploy repository>
make alert STATUS=resolved
```

## Run it on your own cluster

1.  Copy `platform/` and `factory/` into the repositories your GitOps tool reads.
2.  In `platform/tenants/oncall.yaml`, replace the `oidc` block with your identity provider's client.
3.  In `platform/models/`, point each route at an `InferenceProvider` you registered.
4.  In `factory/shared/cluster-connection.yaml`, set `baseHost` to your API server and `caCert` to its CA certificate.
5.  Create a `ClusterSecretStore` named `example-secret-store`. Store the App's private key under `oncall-github-app`, the GitHub webhook secret under `oncall-github-webhook` and the Alertmanager token under `oncall-alertmanager-webhook`.
6.  Point an Alertmanager webhook receiver at the alertmanager source's URL, with the token as its bearer.
7.  Install OpenCost with `opencost.mcp.enabled: true`. `quickstart/values/opencost.yaml` shows the values for a cluster without Prometheus.

See [Declarative resources](https://github.com/runkora/kora/blob/main/docs/guides/declarative-resources.md), [Register a connection](https://github.com/runkora/kora/blob/main/docs/guides/register-connection.md) and [Create a trigger](https://github.com/runkora/kora/blob/main/docs/guides/create-a-trigger.md) for the resources the factory uses.
