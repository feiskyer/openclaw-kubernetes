# Changelog

## v0.1.30 (2026-03-10)

- Bump LiteLLM image to `main-1.81.12-stable.3`
- Enable network access in Codex sandbox_workspace_write mode
- Add sessions.visibility=all to tools config

## v0.1.29 (2026-03-10)

- Add ACP agent support with bundled acpx plugin: register plugin and pre-install npm deps in Docker image, render full ACP config (dispatch, allowedAgents, maxConcurrentSessions, stream, runtime) and acpx plugin settings (permissionMode, nonInteractivePermissions, plugins.allow/installs/load) into openclaw.json, seed `~/.acpx/config.json` with per-agent command overrides (codex-acp adapter), add `model` field to claude settings.json for claude-agent-acp compatibility
- Set tools.profile to `full` by default so coding/system tools are always available
- Bump openclaw npm package to 2026.3.8

## v0.1.28 (2026-03-05)

- Add optional Tailscale mesh VPN support: install tailscaled/tailscale binaries in Docker image, run as conditional supervisord processes, register each pod as a unique Tailscale device with configurable hostname, optional HTTPS proxy via `tailscale serve`, and emptyDir state for re-authentication on restart
- Switch Tailscale to kernel networking by default (`tailscale.userspace: false`)
- Disable device auth (`dangerouslyDisableDeviceAuth`) for Control UI when Tailscale is enabled, allowing access over the trusted Tailscale network
- Enable partial streaming for Telegram responses
- Add `permissions` to code scanning workflow
- Bump docker/login-action from 3.7.0 to 4.0.0

## v0.1.27 (2026-03-04)

- Add external skills loading via PVC/NFS volumes: new `openclaw.skills.volumes` convenience field mounts volumes and auto-wires their paths into `skills.load.extraDirs` in `openclaw.json`; support `openclaw.skills.load.extraDirs/watch/watchDebounceMs` for fine-grained control; add Azure Blob NFS example manifests
- Add dmAccess examples for Telegram and Slack in README
- Bump openclaw npm package to 2026.3.2
- Bump LiteLLM image to `main-v1.81.14-stable`

## v0.1.26 (2026-03-03)

- Add optional NetworkPolicy for OpenClaw and LiteLLM pods that blocks egress to cloud IMDS (169.254.169.254) while allowing all other traffic; disabled by default (`networkPolicy.enabled: false`)

## v0.1.25 (2026-03-03)
- Fix Service selector matching both OpenClaw and LiteLLM pods by adding `app.kubernetes.io/component: gateway` label to OpenClaw selector labels
- Add selector-isolation test (`helm-test-selectors.sh`) to CI that validates each Service matches exactly one workload and all workloads have distinct component labels

## v0.1.24 (2026-03-03)

- Add ttyd web-based terminal: install ttyd binary (pinned v1.7.7, multi-arch x86_64/aarch64) in Docker image, run as conditional supervisord process with `--base-path` synced to values, expose via Service port and optional Ingress; enabled by default (cluster-internal only), ingress requires explicit opt-in
- Switch readinessProbe to `/ready` endpoint (previously `/health`)
- Set Slack `replyToMode` to `"all"` when Slack channel is enabled
- Add `openclaw.dmAccess` config for per-channel DM policy and `allowFrom` user filtering
- Bump openclaw npm package to 2026.3.1
- Add `CLAWHUB_WORKDIR` env var to Dockerfile
- Bump LiteLLM image to `main-v1.81.12-stable.2`
- Bump Node base image from 24-slim to 25-slim
- Bump CI dependencies: actions/checkout v6, docker/build-push-action v6.19.2, docker/login-action v3.7.0, docker/metadata-action v5.10.0, docker/setup-buildx-action v3.12.0
- Add Dependabot configuration for GitHub Actions and Docker dependencies
- Fix publish-chart workflow to trigger only on version tag pushes
- Fix Docker validation workflow by adding build cache
- Add manual dependency bump guide to CLAUDE.md

## v0.1.23 (2026-02-28)

- Fix init script breaking first-run PVC seeding: skills sync before sentinel check created `.openclaw/` early, causing the skeleton copy (`cp -r /home/vibe/. /home-data/`) to be skipped — resulting in missing `.zshrc`, `claude` CLI, and other dotfiles; moved skills sync inside the sentinel block so it only runs on subsequent boots

## v0.1.22 (2026-02-28)

- Add built-in skills support: ship `claude-skill` and `codex-skill` in the container image at `~/.openclaw/skills/`, teaching the OpenClaw agent how to operate Claude Code and Codex CLI as managed coding sub-agents
- Update init script to seed new built-in skills to PVC on every pod start without overwriting existing or user-customized skills
- Document skills in README (included skills, upgrade behavior, adding custom skills) and add `skills/README.md` with skill structure and authoring guide

## v0.1.21 (2026-02-27)

- Pin npm packages in Dockerfile: `openclaw@2026.2.26`, `clawhub@0.7.0` with ARG declarations for build-time overrides
- Pin LiteLLM image from `main-latest` to `main-v1.81.12-stable.1` across all values files
- Set `appVersion` to match chart version (previously `latest`); development/minimal values files now use `tag: ""` to inherit appVersion

## v0.1.20 (2026-02-26)

- Add noVNC ingress routes: creates separate ingress resources for the noVNC web UI (`/vnc/(.*)` → port 6080 with rewrite) and WebSocket (`/websockify` → port 6080) when `novnc.ingress.enabled`; the dedicated WebSocket route prevents noVNC's absolute `/websockify` path from hitting the gateway ingress and failing
- Set `browser.attachOnly=true` in default config so OpenClaw attaches to the supervisord-managed Chrome instance instead of launching its own
- Add Azure Workload Identity support: new `azureWorkloadIdentity.enabled/clientId` values; when enabled, annotates the service account with `azure.workload.identity/client-id`, labels the pod with `azure.workload.identity/use`, and forces `automountServiceAccountToken: true` (required for token projection); prerequisites: AKS cluster with OIDC issuer + workload identity enabled and a federated credential linking the managed identity to the service account

## v0.1.19 (2026-02-26)

- Remove `helm.sh/resource-policy: keep` annotation from both secret templates so secrets follow normal Helm lifecycle
- Make openclaw secret annotations conditional on `.Values.secrets.annotations` being set
- Auto-launch Chrome as a supervised process on virtual display for noVNC; Chrome runs with remote debugging port 18800 for CDP attachment
- Switch liveness/readiness/startup probes from exec to httpGet on `/health`; remove `nginx.ingress.kubernetes.io/configuration-snippet` from default ingress values (disabled by default in nginx ingress controller)

## v0.1.18 (2026-02-26)

- Use ConfigMap for codex and claude configs instead of baked-in image files; init container seeds `codex-config.toml` and `claude-settings.json` from ConfigMap on every pod start
- Set WORKDIR to `/home/vibe` and update codex config defaults
- Fix embedding API base URL in README

## v0.1.17 (2026-02-25)

- Fix memory search credential exposure — move embedding `apiKey`, `apiBase`, and `provider` from `openclaw.memorySearch.*` (ConfigMap) into `litellm.secrets.embeddingApiKey/embeddingApiBase/embeddingProvider` (LiteLLM Secret); `openclaw.json` now points at the LiteLLM service URL with a dummy key
- Route memory search embedding requests through LiteLLM proxy; add embedding model entry (`mode: embedding`) to LiteLLM `model_list` when `embeddingApiKey` is set; embedding provider is independently configurable from the main chat model provider
- Disable embedding batch mode and set concurrency to 8

## v0.1.16 (2026-02-24)

- Fix Node 22+ Happy Eyeballs (autoSelectFamily) breaking Telegram and external API calls on dual-stack clusters — add `NODE_OPTIONS=--dns-result-order=ipv4first` to container env
- Fix Telegram connectivity on dual-stack clusters — inject `channels.telegram.network.autoSelectFamily: false` into `openclaw.json` (applies to both gateway and embedded agent modes)
- Add `secrets.telegramTokenFile` — read bot token from a mounted file instead of env var for better security
- Fix init container running slow `cp -r` and `chown -R` on every pod restart — use sentinel file to skip entirely after first initialization, preserving customer data and speeding up restarts

## v0.1.15 (2026-02-24)

- Switch to headed Chrome with noVNC GUI access on port 6080 (supervisord manages Xvfb, Fluxbox, x11vnc, noVNC, openclaw)
- Fix LiteLLM API format detection to use `contains "claude"` instead of `hasPrefix`, fixing `vertex_ai/claude-*` models
- Add `gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback` to allow non-loopback gateway binding
- Add supervisorctl socket support to entrypoint.sh

## v0.1.14 (2026-02-24)

- Skip slow `chown -R` on subsequent Pod restarts in init-home container

## v0.1.13 (2026-02-24)

- Add compaction config with memoryFlush to agent defaults
- Add optional memory search (semantic search over conversation history), enabled when both baseUrl and apiKey are provided

## v0.1.12 (2026-02-24)

- Remove unused probe exec.command and relax liveness probe timing
- Add Azure File StorageClass example and persistence docs
- Add version bump steps to CLAUDE.md

## v0.1.11 (2026-02-12)

- Fix sudo permission issues

## v0.1.10 (2026-02-12)

- Sudo enabled by default via securityContext (CAP_SETUID, CAP_SETGID, allowPrivilegeEscalation)
- Set readOnlyRootFilesystem=false by default (required for package managers like apt/yum)

## v0.1.9 (2026-02-12)

- Auto-enable channel plugins when bot tokens are configured (Telegram/Discord require single token; Slack/Feishu/Teams require all credentials)

## v0.1.8 (2026-02-12)

- Changed persistent volume to mount entire `/home/vibe` directory (plugins, configs, tools all persisted)
- Renamed init container to `init-home-data` with simplified seeding logic
- Pinned npm to v11.6.0 in Dockerfile to address ECOMPROMISED issue
- Increased default persistence size from 10Gi to 100Gi
- Added `fsGroupChangePolicy: OnRootMismatch` for faster pod startup
- Enabled service account token automount by default
- Set default service account role to "view" for read-only Kubernetes access

## v0.1.7 (2026-02-12)

- Preserved agent defaults when merging LiteLLM config (no longer overwrites existing settings)
- Enabled verbose mode by default for agents
- Installed Azure CLI in the container image
- Added a default kubeconfig for vibe user

## v0.1.6 (2026-02-10)

- Added Feishu and Microsoft Teams channel support
- Added Brave and Perplexity web search integration (auto-enables when API key is set)
- Pre-installed channel plugins and clawhub in container image
- Reorganized README with collapsible sections and quick reference tables

## v0.1.5 (2026-02-09)

- Added browser configuration for Claude Code and Codex clients
- Relaxed readiness probe thresholds for better stability
- Replaced chromium with google-chrome-stable in Dockerfile
- Dropped arm64 support to simplify build process
- Added kubectl installation to container image
- Added optional service account role binding for Kubernetes operations
- Refactored model configuration to be fully templated
- Added wildcard routing support for LiteLLM proxy

## v0.1.4 (2026-02-09)

- Switched to openclaw CLI entrypoint for improved startup
- Updated container user UID/GID to 1024 for better compatibility
- Fixed LiteLLM runAsUser configuration
- Fixed Docker latest tag handling
- Fixed Dockerfile build issues
- Added LiteLLM proxy deployment with Codex and Claude configurations
- Improved Dockerfile with development tools and proper user setup
- Cleaned up unnecessary deployment steps

## v0.1.2

- Hardened default security settings and added autoscaling/secret validations.
- Fixed pod annotation scoping and ensured checksum rollouts.
- Added OSS community and security documentation.
