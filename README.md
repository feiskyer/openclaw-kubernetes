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

1) (Alternative) Use a specific model provider (e.g. Anthropic):

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

<details>
<summary>How it works</summary>

- LiteLLM runs as a separate Deployment with its own Service (`<release>-litellm:4000`)
- The OpenClaw ConfigMap (`openclaw.json`) is automatically configured to route model requests through the LiteLLM proxy
- LiteLLM handles provider-specific API translation (Anthropic, OpenAI, GitHub Copilot, etc.)
- Provider credentials live exclusively in the `<release>-litellm` Secret and are only mounted into the LiteLLM pod

</details>

<details>
<summary>Provider configuration</summary>

Set the model provider via `litellm.secrets`:

| Provider | `litellm.secrets.provider` | `litellm.secrets.apiKey` | Notes |
|---|---|---|---|
| GitHub Copilot | `github_copilot` (default) | Not needed | Uses editor auth headers |
| Anthropic | `anthropic` | Required | Direct Anthropic API |
| OpenAI | `openai` | Required | Direct OpenAI API |

For providers with custom endpoints, set `litellm.secrets.apiBase` to the base URL.

</details>

<details>
<summary>Model selection</summary>

Set `litellm.model` to configure which model to proxy (default: `claude-opus-4.6`). The API format in `openclaw.json` is automatically determined:

- `claude*` models use `anthropic-messages`
- `gpt*` models use `openai-responses`
- Other models use `openai-completions`

</details>

<details>
<summary>Custom LiteLLM config</summary>

To override the built-in config entirely, set `litellm.configOverride` with your complete LiteLLM YAML config.

</details>

## Values and configuration

### Quick reference

| Value | Default | Description |
|-------|---------|-------------|
| `secrets.openclawGatewayToken` | `""` | **Required.** Gateway authentication token |
| `litellm.enabled` | `true` | Enable LiteLLM proxy for model routing |
| `litellm.model` | `claude-opus-4.6` | Model to proxy through LiteLLM |
| `litellm.secrets.provider` | `github_copilot` | Model provider (`github_copilot`, `anthropic`, `openai`) |
| `persistence.enabled` | `true` | Enable persistent storage |
| `persistence.size` | `10Gi` | Storage size for OpenClaw data |
| `ingress.enabled` | `false` | Enable Ingress for external access |
| `service.type` | `ClusterIP` | Service type (`ClusterIP`, `NodePort`, `LoadBalancer`) |

See dedicated sections below for [Secrets](#secrets), [Messaging Platforms](#messaging-platforms), [Web Search](#web-search), and [LiteLLM Proxy](#litellm-proxy).

<details>
<summary>Image and replicas</summary>

| Value | Default | Description |
|-------|---------|-------------|
| `replicaCount` | `1` | Must be 1 (OpenClaw is single-instance) |
| `image.repository` | `ghcr.io/feiskyer/openclaw-gateway` | Container image |
| `image.tag` | `""` | Image tag (defaults to chart appVersion) |
| `image.pullPolicy` | `Always` | Image pull policy |
| `imagePullSecrets` | `[]` | Pull secrets for private registries |

</details>

<details>
<summary>Service and networking</summary>

| Value | Default | Description |
|-------|---------|-------------|
| `service.type` | `ClusterIP` | Service type |
| `service.port` | `18789` | Service port |
| `service.nodePort` | `null` | NodePort (when type is NodePort) |
| `ingress.enabled` | `false` | Enable Ingress |
| `ingress.className` | `""` | Ingress class name |
| `ingress.hosts` | `[{host: openclaw.local, ...}]` | Ingress hosts |
| `ingress.tls` | `[]` | TLS configuration |

</details>

<details>
<summary>Resources and probes</summary>

| Value | Default | Description |
|-------|---------|-------------|
| `resources.requests.cpu` | `250m` | CPU request |
| `resources.requests.memory` | `1Gi` | Memory request |
| `resources.limits.cpu` | `2000m` | CPU limit |
| `resources.limits.memory` | `8Gi` | Memory limit |
| `livenessProbe.enabled` | `true` | Enable liveness probe |
| `readinessProbe.enabled` | `true` | Enable readiness probe |
| `startupProbe.enabled` | `false` | Enable startup probe |

</details>

<details>
<summary>Service account and security</summary>

| Value | Default | Description |
|-------|---------|-------------|
| `serviceAccount.create` | `true` | Create service account |
| `serviceAccount.role` | `""` | Bind to ClusterRole (`view`, `cluster-admin`, or empty) |
| `podSecurityContext.runAsNonRoot` | `true` | Run as non-root user |
| `securityContext.allowPrivilegeEscalation` | `true` | Allow privilege escalation (required for sudo) |
| `securityContext.capabilities.add` | `[CAP_SETUID, CAP_SETGID]` | Capabilities for sudo |

</details>

<details>
<summary>Scheduling and availability</summary>

| Value | Default | Description |
|-------|---------|-------------|
| `nodeSelector` | `{}` | Node selector |
| `tolerations` | `[]` | Pod tolerations |
| `affinity` | `{}` | Pod affinity rules |
| `topologySpreadConstraints` | `[]` | Topology spread constraints |
| `podDisruptionBudget.enabled` | `false` | Enable PDB |

</details>

<details>
<summary>Extensions</summary>

| Value | Default | Description |
|-------|---------|-------------|
| `extraEnv` | `[]` | Extra environment variables |
| `extraEnvFrom` | `[]` | Extra env from secrets/configmaps |
| `extraVolumes` | `[]` | Extra volumes |
| `extraVolumeMounts` | `[]` | Extra volume mounts |
| `initContainers` | `[]` | Additional init containers |
| `sidecars` | `[]` | Sidecar containers |

</details>

### Preset values files

| File | Use case |
|------|----------|
| `values.yaml` | Full defaults with security hardening |
| `values-minimal.yaml` | CI/testing (no security context, no persistence) |
| `values-development.yaml` | Local dev (NodePort, relaxed security, debug logging) |
| `values-production.yaml` | Production (Ingress + TLS, anti-affinity, backup annotations) |

## Persistence and data directory

<details>
<summary>Storage configuration details</summary>

- Data volume mounted at `/home/vibe/.openclaw` (`OPENCLAW_STATE_DIR`).
- An init container seeds the volume from the image when the PVC is empty.
- Config (`openclaw.json`) is seeded from the ConfigMap if not already present.
- When `persistence.enabled` is `false`, an `emptyDir` volume is used instead of a PVC.
- To use a pre-provisioned volume, set `persistence.existingClaim`.
- LiteLLM has its own PVC (`litellm.persistence.*`) mounted at `~/.config/litellm`.

</details>

## Secrets

Two modes:

1) Set values under `secrets.*` and let the chart create a Secret.
2) Reference an existing secret via `secrets.existingSecret`.

<details>
<summary>Expected keys for an existing secret</summary>

- `OPENCLAW_GATEWAY_TOKEN` (required)
- `TELEGRAM_BOT_TOKEN` (optional)
- `DISCORD_BOT_TOKEN` (optional)
- `SLACK_BOT_TOKEN` (optional)
- `SLACK_APP_TOKEN` (optional)
- `FEISHU_APP_ID` (optional)
- `FEISHU_APP_SECRET` (optional)
- `MSTEAMS_APP_ID` (optional)
- `MSTEAMS_APP_PASSWORD` (optional)
- `MSTEAMS_TENANT_ID` (optional)
- `BRAVE_API_KEY` (optional)
- `PERPLEXITY_API_KEY` (optional)

</details>

`secrets.openclawGatewayToken` is required when not using `secrets.existingSecret`.

LiteLLM has its own secret (`<release>-litellm`) with keys `apiKey` and `apiBase`, configured via `litellm.secrets.*`.

## Messaging Platforms

OpenClaw supports multiple messaging platforms. Configure credentials via `secrets.*` values or an existing secret.

<details>
<summary>Discord</summary>

| Value | Environment Variable | Description |
|-------|---------------------|-------------|
| `secrets.discordBotToken` | `DISCORD_BOT_TOKEN` | Bot token from Discord Developer Portal |

```bash
helm install openclaw oci://ghcr.io/feiskyer/openclaw-kubernetes/openclaw \
  --set secrets.openclawGatewayToken=$gatewayToken \
  --set secrets.discordBotToken=<your-discord-bot-token>
```

📖 [Discord Setup Guide](https://docs.openclaw.ai/channels/discord)

</details>

<details>
<summary>Telegram</summary>

| Value | Environment Variable | Description |
|-------|---------------------|-------------|
| `secrets.telegramBotToken` | `TELEGRAM_BOT_TOKEN` | Bot token from [@BotFather](https://t.me/BotFather) |

```bash
helm install openclaw oci://ghcr.io/feiskyer/openclaw-kubernetes/openclaw \
  --set secrets.openclawGatewayToken=$gatewayToken \
  --set secrets.telegramBotToken=<your-telegram-bot-token>
```

📖 [Telegram Setup Guide](https://docs.openclaw.ai/channels/telegram)

</details>

<details>
<summary>Slack</summary>

| Value | Environment Variable | Description |
|-------|---------------------|-------------|
| `secrets.slackBotToken` | `SLACK_BOT_TOKEN` | Bot user OAuth token (`xoxb-...`) |
| `secrets.slackAppToken` | `SLACK_APP_TOKEN` | App-level token (`xapp-...`) |

```bash
helm install openclaw oci://ghcr.io/feiskyer/openclaw-kubernetes/openclaw \
  --set secrets.openclawGatewayToken=$gatewayToken \
  --set secrets.slackBotToken=xoxb-... \
  --set secrets.slackAppToken=xapp-...
```

📖 [Slack Setup Guide](https://docs.openclaw.ai/channels/slack)

</details>

<details>
<summary>Feishu (Lark)</summary>

| Value | Environment Variable | Description |
|-------|---------------------|-------------|
| `secrets.feishuAppId` | `FEISHU_APP_ID` | App ID (`cli_xxx`) from Feishu Open Platform |
| `secrets.feishuAppSecret` | `FEISHU_APP_SECRET` | App Secret (keep private) |

```bash
helm install openclaw oci://ghcr.io/feiskyer/openclaw-kubernetes/openclaw \
  --set secrets.openclawGatewayToken=$gatewayToken \
  --set secrets.feishuAppId=cli_xxx \
  --set secrets.feishuAppSecret=<your-app-secret>
```

📖 [Feishu Setup Guide](https://docs.openclaw.ai/channels/feishu)

</details>

<details>
<summary>Microsoft Teams</summary>

| Value | Environment Variable | Description |
|-------|---------------------|-------------|
| `secrets.msteamsAppId` | `MSTEAMS_APP_ID` | Azure Bot Application ID |
| `secrets.msteamsAppPassword` | `MSTEAMS_APP_PASSWORD` | Client secret from Azure Portal |
| `secrets.msteamsTenantId` | `MSTEAMS_TENANT_ID` | Directory (tenant) ID |

```bash
helm install openclaw oci://ghcr.io/feiskyer/openclaw-kubernetes/openclaw \
  --set secrets.openclawGatewayToken=$gatewayToken \
  --set secrets.msteamsAppId=<azure-app-id> \
  --set secrets.msteamsAppPassword=<client-secret> \
  --set secrets.msteamsTenantId=<tenant-id>
```

📖 [Microsoft Teams Setup Guide](https://docs.openclaw.ai/channels/msteams)

</details>

## Web Search

OpenClaw supports web search via Brave or Perplexity. When an API key is configured, `tools.web.search` is automatically enabled in `openclaw.json`.

<details>
<summary>Brave Search</summary>

Structured results (title, URL, snippet) with a free tier available.

| Value | Environment Variable | Description |
|-------|---------------------|-------------|
| `secrets.braveApiKey` | `BRAVE_API_KEY` | Brave Search API key |

```bash
helm install openclaw oci://ghcr.io/feiskyer/openclaw-kubernetes/openclaw \
  --set secrets.openclawGatewayToken=$gatewayToken \
  --set secrets.braveApiKey=<your-brave-api-key>
```

</details>

<details>
<summary>Perplexity</summary>

AI-synthesized answers with citations from real-time web search.

| Value | Environment Variable | Description |
|-------|---------------------|-------------|
| `secrets.perplexityApiKey` | `PERPLEXITY_API_KEY` | Perplexity API key |

```bash
helm install openclaw oci://ghcr.io/feiskyer/openclaw-kubernetes/openclaw \
  --set secrets.openclawGatewayToken=$gatewayToken \
  --set secrets.perplexityApiKey=<your-perplexity-api-key>
```

</details>

📖 [Web Search Documentation](https://docs.openclaw.ai/tools/web)

## Development

```bash
# Lint the chart
./scripts/helm-lint.sh

# Render templates with each values file
./scripts/helm-test.sh

# Ad-hoc template rendering
helm template openclaw . -f values.yaml
```

<details>
<summary>Publishing</summary>

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

</details>

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

## Links

- [OpenClaw](https://openclaw.ai/) (formerly Moltbot/Clawdbot)
- [OpenClaw Documentation](https://docs.openclaw.ai/)
- [AI Agent Community](https://www.moltbook.com/)
- [Source Code](https://github.com/openclaw/openclaw)

## Acknowledgments

<details>
<summary>OpenClaw Project</summary>

This Helm chart deploys [OpenClaw](https://openclaw.ai/), an open-source personal AI assistant gateway. Thanks to the OpenClaw team for building and maintaining this project.

- [OpenClaw Website](https://openclaw.ai/)
- [OpenClaw Documentation](https://docs.openclaw.ai/)
- [OpenClaw Source Code](https://github.com/openclaw/openclaw)

</details>

<details>
<summary>Original Helm Chart PR</summary>

This chart is forked from [openclaw/openclaw#2562](https://github.com/openclaw/openclaw/pull/2562/). The original PR was not accepted upstream, so this repository continues the work with further improvements. Thanks to the original author for the initial draft.

</details>

## License

This project is licensed under the [MIT License](LICENSE).
