# OpenClaw Helm Chart

Helm chart for [OpenClaw](https://openclaw.ai/) (gateway). Deploys a single-instance StatefulSet with persistent storage, secrets management, and an optional [LiteLLM](https://github.com/BerriAI/litellm) proxy for model routing.

## Requirements

- Helm v3
- A Kubernetes cluster with PersistentVolume support (optional if persistence is disabled)

## Install

Charts are published as OCI artifacts in GHCR.

1) Create a Telegram bot via [@BotFather](https://t.me/BotFather):

   - Message [@BotFather](https://t.me/BotFather), send `/newbot`, and follow the prompts
   - Save the token: `export telegramBotToken=<your-token>`

1) Generate a gateway token:

   ```bash
   export gatewayToken=$(openssl rand -hex 32)
   ```

1) Install the chart:

   ```bash
   helm install openclaw oci://ghcr.io/feiskyer/openclaw-kubernetes/openclaw \
      --create-namespace --namespace openclaw \
      --set secrets.openclawGatewayToken=$gatewayToken \
      --set secrets.telegramBotToken=$telegramBotToken
   ```

   This deploys the OpenClaw gateway and a LiteLLM proxy with Github Copilot provider (enabled by default).

1) (Optional) Use a specific model provider instead of the default GitHub Copilot:

   ```bash
   helm install openclaw oci://ghcr.io/feiskyer/openclaw-kubernetes/openclaw \
      --create-namespace --namespace openclaw \
      --set secrets.openclawGatewayToken=$gatewayToken \
      --set secrets.telegramBotToken=$telegramBotToken \
      --set litellm.secrets.provider=anthropic \
      --set litellm.secrets.apiKey=<your-api-key> \
      --set litellm.secrets.apiBase=<your-api-base> \
      --set litellm.model=claude-opus-4.6
   ```

1) Access the portal:

   ```bash
   kubectl --namespace openclaw port-forward openclaw-0 18789:18789
   ```

   Then open <http://localhost:18789/?token=$gatewayToken> in your browser.

## Upgrade / Uninstall

```bash
# Upgrade
helm upgrade openclaw oci://ghcr.io/feiskyer/openclaw-kubernetes/openclaw \
  --namespace openclaw \
  --set secrets.openclawGatewayToken=$gatewayToken \
  --set secrets.telegramBotToken=$telegramBotToken

# Uninstall
helm uninstall openclaw --namespace openclaw
```

## LiteLLM Proxy

The chart includes a [LiteLLM](https://github.com/BerriAI/litellm) proxy between OpenClaw and model providers, enabled by default (`litellm.enabled: true`).

LiteLLM provides:

1. **Provider decoupling** -- OpenClaw talks only to the local LiteLLM endpoint. Switching providers (e.g. GitHub Copilot to Anthropic) requires only a Helm values change.
2. **Credential isolation** -- API keys live in the LiteLLM Secret and are never injected into the OpenClaw container. OpenClaw authenticates to LiteLLM with a dummy token over the cluster-internal network.

### How it works

- LiteLLM runs as a separate Deployment with its own Service (`<release>-litellm:4000`)
- The OpenClaw ConfigMap (`openclaw.json`) is automatically configured to route model requests through the LiteLLM proxy
- LiteLLM handles provider-specific API translation (Anthropic, OpenAI, GitHub Copilot, etc.)
- Provider credentials live exclusively in the `<release>-litellm` Secret and are only mounted into the LiteLLM pod

### Provider configuration

Set the model provider via `litellm.secrets`:

| Provider | `litellm.secrets.provider` | `litellm.secrets.apiKey` | Notes |
|---|---|---|---|
| GitHub Copilot | `github_copilot` (default) | Not needed | Uses editor auth headers |
| Anthropic | `anthropic` | Required | Direct Anthropic API |
| OpenAI | `openai` | Required | Direct OpenAI API |

For providers with custom endpoints, set `litellm.secrets.apiBase` to the base URL.

### Model selection

Set `litellm.model` to configure which model to proxy (default: `claude-opus-4.6`). The API format in `openclaw.json` is automatically determined:

- `claude*` models use `anthropic-messages`
- `gpt*` models use `openai-responses`
- Other models use `openai-completions`

### Custom LiteLLM config

To override the built-in config entirely, set `litellm.configOverride` with your complete LiteLLM YAML config.

## FAQ

<details>
<summary>How to use a free model?</summary>

Run the onboard script and select **QWen** or **OpenCode Zen**, then pick a free model:

```bash
kubectl -n openclaw exec -it openclaw-0 -- node openclaw.mjs onboard
```

Example with OpenCode Zen:

![OpenCode Zen Setup](images/opencode-zen-setup.png)

</details>

<details>
<summary>How to join the Moltbook community?</summary>

Send this prompt to your OpenClaw agent:

```
Read https://moltbook.com/skill.md and follow the instructions to join Moltbook
```

</details>

<details>
<summary>How to modify configuration after deployment?</summary>

Run the onboard command:

```bash
kubectl -n openclaw exec -it openclaw-0 -- node openclaw.mjs onboard
```

</details>

<details>
<summary>How to authorize Telegram users?</summary>

Add your user ID in **Channel -> Telegram -> Allow From**. Get your ID by messaging [@userinfobot](https://t.me/userinfobot).

</details>

<details>
<summary>How to fix "disconnected (1008): pairing required" error?</summary>

List pending device requests and approve yours:

```bash
kubectl -n openclaw exec -it openclaw-0 -- node dist/index.js devices list
kubectl -n openclaw exec -it openclaw-0 -- node dist/index.js devices approve <your-request-id>
```

</details>

## Values and configuration

Key values:

- `image.*`: container image settings.
- `replicaCount`: must be `1` (OpenClaw is single-instance).
- `service.*`: Service type/ports/annotations.
- `resources.*`: CPU/memory requests/limits.
- `persistence.*`: PVC configuration for OpenClaw data.
- `secrets.*`: messaging tokens and gateway token, or reference an existing secret.
- `openclaw.config`: OpenClaw gateway configuration (rendered into `openclaw.json`).
- `litellm.*`: LiteLLM proxy configuration (enabled by default).
- `litellm.model`: model to proxy (default: `claude-opus-4.6`).
- `litellm.secrets.*`: provider, API key, and base URL for the model provider.
- `litellm.persistence.*`: PVC configuration for LiteLLM data.
- `extraEnv`, `extraEnvFrom`, `extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`: extensions.

Preset values files:

- `values-minimal.yaml`: minimal defaults for testing.
- `values-development.yaml`: development-focused defaults.
- `values-production.yaml`: production-leaning defaults.

See `values.yaml` for the full list and `values.schema.json` for schema validation.

## Persistence and data directory

- Data volume mounted at `/home/vibe/.openclaw` (`OPENCLAW_STATE_DIR`).
- An init container seeds the volume from the image when the PVC is empty.
- Config (`openclaw.json`) is seeded from the ConfigMap if not already present.
- When `persistence.enabled` is `false`, an `emptyDir` volume is used instead of a PVC.
- To use a pre-provisioned volume, set `persistence.existingClaim`.
- LiteLLM has its own PVC (`litellm.persistence.*`) mounted at `~/.config/litellm`.

## Secrets

Two modes:

1) Set values under `secrets.*` and let the chart create a Secret.
2) Reference an existing secret via `secrets.existingSecret`.

Expected keys for an existing secret:

- `OPENCLAW_GATEWAY_TOKEN` (required)
- `TELEGRAM_BOT_TOKEN` (optional)
- `DISCORD_BOT_TOKEN` (optional)
- `SLACK_BOT_TOKEN` (optional)
- `SLACK_APP_TOKEN` (optional)

`secrets.openclawGatewayToken` is required when not using `secrets.existingSecret`.

LiteLLM has its own secret (`<release>-litellm`) with keys `apiKey` and `apiBase`, configured via `litellm.secrets.*`.

## Development

```bash
# Lint the chart
./scripts/helm-lint.sh

# Render templates with each values file
./scripts/helm-test.sh

# Ad-hoc template rendering
helm template openclaw . -f values.yaml
```

## Publishing (maintainers)

Charts are published to GHCR as OCI artifacts on pushes to `main`.

Manual publish:

```bash
helm registry login ghcr.io -u <github-username> -p <github-token>
./scripts/publish-chart.sh
```

Environment overrides:

- `CHART_DIR`: chart directory (default: `.`)
- `CHART_OCI_REPO`: OCI repo (default: `ghcr.io/feiskyer/openclaw-kubernetes` based on `GITHUB_REPOSITORY`)

Bump `Chart.yaml` version before each release; OCI registries reject duplicate versions.

## Links

- [OpenClaw](https://openclaw.ai/) (formerly Moltbot/Clawdbot)
- [AI Agent Community](https://www.moltbook.com/)
- [Source Code](https://github.com/openclaw/openclaw)

## Acknowledgments

This chart is forked from [openclaw/openclaw#2562](https://github.com/openclaw/openclaw/pull/2562/). The original PR was not accepted upstream, so this repository continues the work with further improvements. Thanks to the original author for the initial draft.

## License

This project is licensed under the [MIT License](LICENSE).
