# Changelog

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
