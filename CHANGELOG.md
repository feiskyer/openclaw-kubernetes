# Changelog

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
