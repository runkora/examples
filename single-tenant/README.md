# Single tenant

This example declares one tenant and one agent that summarises pull requests. It has two GitOps repositories: the platform team's and the tenant team's. It runs on the [quickstart](../quickstart) with no setup beyond a model provider.

## Files

*   **`platform/`:** The platform team's repository.
    *   `tenants/example.yaml`: The `KoraTenant` `example`, whose namespace the operator creates as `kora-tenant-example`.
    *   `models/`: The `VirtualModel`s in `kora-system`. Three route to OpenRouter and `openai/gpt-oss-20b` routes to Ollama.
*   **`tenant/`:** The tenant team's repository, applied to `kora-tenant-example`.
    *   `kustomization.yaml`: Sets the namespace and the `runkora.io/repository` annotation. The resource files leave `namespace` out.
    *   `environment.yaml`: The `Environment` `pr-tools`. It sets the sandbox image, the bundled `kora-python`, and the size.
    *   `agent.yaml`: The `Agent` `pr-summariser`. It runs on the `anthropic/claude-haiku-5-5` model in `pr-tools` and holds its own egress to GitHub.
    *   `trigger-source.yaml`: The GitHub `TriggerSource` and the `ExternalSecret` that supplies its signing secret.
    *   `triggers.yaml`: A webhook `Trigger` for new pull requests and a manual `Trigger` that takes a pull request URL.
    *   `role.yaml`: The `PolicyRole` `engineer`. It lets the `engineer` group see the agent and the triggers, read and start the agent's runs, and fire the manual trigger.

## Run the example

On the quickstart, choose `single-tenant` when `make up` asks, or run `make example EXAMPLE=single-tenant`. To apply it by hand:

```bash
kubectl apply -k single-tenant/platform
kubectl get namespace kora-tenant-example
kubectl apply -k single-tenant/tenant
kubectl get environments,agents.runkora.io,triggersources,triggers.runkora.io,policyroles -n kora-tenant-example
```

Each resource reports `Ready=True` once the resources it references are ready. Sign in as `admin@local.runkora.io`, open the `summarise-pr` trigger and fire it with a public pull request URL.

## How the agent reaches a model

The agent in `tenant/` uses the model `anthropic/claude-haiku-5-5`. `platform/models/` declares the models and routes each to a provider, `compatible:openrouter` or `compatible:ollama`. The [quickstart](../quickstart) registers its providers in `quickstart/providers/`, for the quickstart only. To run on Ollama, set the agent's `model` to `openai/gpt-oss-20b` as described in [Choose a model provider](../quickstart/README.md#choose-a-model-provider). The tenant references no provider. A change to where a model runs touches its file in `platform/models/` alone.

## Connect the webhook

1.  Read the webhook path from the source:

    ```bash
    kubectl get triggersources github -n kora-tenant-example -o wide
    ```

2.  In GitHub, add a webhook to a repository with the URL set to your kora API host plus that path.
3.  Set the webhook secret to the value of the `github-webhook` Secret in `kora-tenant-example`.
4.  Select the pull request event.

On the quickstart, run `make tunnel` first and use the webhook URL it prints, as described in [Receive webhooks locally](../quickstart/README.md#receive-webhooks-locally).

## Run it on your own cluster

1.  Copy `platform/` and `tenant/` into the repositories your GitOps tool reads.
2.  In `platform/tenants/example.yaml`, replace the `oidc` block with the client your identity provider gives you, and set `emailDomains` to your domains. Drop `claimBinding` when no other tenant shares the domain.
3.  In `platform/models/`, point each route at an `InferenceProvider` you registered.
4.  Create a `ClusterSecretStore` named `example-secret-store` that points at your secret manager, and store the webhook signing secret under the key `example-github-webhook`.
5.  Set `runkora.io/repository` in each `kustomization.yaml` to your repository.

Anyone who can write these kinds can give a tenant's agents and users any scope. Grant write access to them only to the identity your GitOps tool runs as.

See [Declarative resources](https://github.com/runkora/kora/blob/main/docs/guides/declarative-resources.md) for every kind and field.
