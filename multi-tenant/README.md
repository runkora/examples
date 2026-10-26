# Multi-tenant

This example declares two tenants, one for an engineering team and one for an SRE team. kora keeps each tenant's people, agents, runs and spend apart. The platform team keeps one repository for the tenants and the model, and each team keeps its own repository for its agents.

## Layout

```
platform/                     The platform team's repository
├── tenants/                  KoraTenant engineering, KoraTenant sre
└── models/                   VirtualModels: three on OpenRouter, openai/gpt-oss-20b on Ollama
engineering/                  The engineering team's repository, applied to kora-tenant-engineering
├── shared/                   Environment go-build, sources github-org and slack, role reviewers, connection github
└── use-cases/
    ├── pr-review/            Agent code-reviewer, Trigger review-on-pr
    ├── weekly-report/        Agent pr-reporter, Trigger monday-report
    └── slack-assistant/      Trigger on-mention, routed to code-reviewer or pr-reporter
sre/                          The SRE team's repository, applied to kora-tenant-sre
├── shared/                   Source alertmanager, role sre, MCP server exa
└── use-cases/
    └── incident-triage/      Agent sre-triage, Trigger on-alert-firing
```

*   **`shared/`:** Resources the team's use cases reference by name. Declare each one once.
*   **`use-cases/`:** One folder per use case, holding its `Agent` and `Trigger` resources.

## Prerequisites

*   **Exa:** The SRE team's `exa` MCP server needs an Exa API key, stored under the key `sre-exa`. On the quickstart, set `EXA_API_KEY` in `.env` and run `make credentials`.
*   **GitHub App:** The engineering team's `github` connection needs a GitHub App installed on your organisation, with its private key stored under the key `engineering-github-app`. On the quickstart, set `GITHUB_APP_PRIVATE_KEY_FILE` in `.env` and run `make credentials`. Set `app_id`, `installation_id` and `owner` in `engineering/shared/connections/github.yaml`.

`make example EXAMPLE=multi-tenant` checks these before it applies the example, and stops with a list of anything missing. After you set them, run `make credentials example EXAMPLE=multi-tenant`.

## Run the example

On the quickstart, choose `multi-tenant` when `make up` asks, or run `make example EXAMPLE=multi-tenant`. To apply it by hand:

```bash
kubectl apply -k multi-tenant/platform
kubectl get namespaces kora-tenant-engineering kora-tenant-sre
kubectl apply -k multi-tenant/engineering
kubectl apply -k multi-tenant/sre
```

Sign in as `admin@engineering.local.runkora.io` or `admin@sre.local.runkora.io`. Each admin sees only their own tenant.

## How the agents reach a model

`code-reviewer` and `sre-triage` use `anthropic/claude-haiku-5-5`, `pr-reporter` uses `deepseek/deepseek-v4-1-flash`, and the `on-mention` trigger picks its agent with the decision model `typesafe/jev-1-14`. `platform/models/` declares the models and routes each to a provider, `compatible:openrouter` or `compatible:ollama`. The [quickstart](../quickstart) registers its providers in `quickstart/providers/`, for the quickstart only. To run on Ollama, set each agent's `model` to `openai/gpt-oss-20b` as described in [Choose a model provider](../quickstart/README.md#choose-a-model-provider). The tenants reference no provider. A change to where a model runs touches its file in `platform/models/` alone.

## Add a use case

1.  Create a folder under the team's `use-cases/` with an `agent.yaml`, a `triggers.yaml` and a `kustomization.yaml` that lists them.
2.  Add the folder to `resources` in the team's `kustomization.yaml`.
3.  Give the agent its own access: `connectors`, `mcpTools` and `connectivity` hosts on the `Agent`. Attach an environment only when the agent needs a different sandbox image or size.
4.  Reference shared environments and trigger sources by name. Add a shared resource when no existing one fits.
5.  Add the agent's run scopes to the roles whose users run it.

## Add a team

1.  Add a `KoraTenant` for the team under `platform/tenants/` with the team's email domain.
2.  Create a repository for the team with a `kustomization.yaml` that sets `namespace: kora-tenant-<team>`.
3.  Point your GitOps tool at the new repository.

## Notes

*   A resource can reference only resources in its own tenant. A routed trigger picks among its own tenant's agents.
*   A `TriggerSource` gets its own webhook path in each tenant. Configure each provider with the path from `status.webhookPath`.
*   Set `apiAuthoring: Disabled` on a tenant to make its repository the only way to change its agents, triggers and roles.

See [Declarative resources](https://github.com/runkora/kora/blob/main/docs/guides/declarative-resources.md) for every kind and field, and [Tenants](https://github.com/runkora/kora/blob/main/docs/guides/tenants.md) for `KoraTenant`.
