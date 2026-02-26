# Changelog

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
