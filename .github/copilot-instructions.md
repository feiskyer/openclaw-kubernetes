# Copilot Code Review Instructions

When performing a code review on this repository, apply the following guidelines.

## Repository Context

This is a Helm chart repository for deploying OpenClaw (a personal AI assistant gateway) to Kubernetes. It includes:
- A Helm chart with templates for a StatefulSet, optional LiteLLM proxy Deployment, ConfigMaps, Secrets, Services, and Ingress
- A Dockerfile for the OpenClaw container image
- Multiple values presets (default, development, production, minimal)
- CI/CD workflows for linting, testing, building, and publishing

## Review Focus Areas

### Helm Templates
- Verify correct use of Helm template functions and named templates from `_helpers.tpl`
- Check that new values are properly referenced with defaults and type safety
- Ensure labels and selectors follow the existing `openclaw.labels` / `openclaw.selectorLabels` conventions
- Validate that changes to `values.yaml` are reflected in `values.schema.json`

### Kubernetes Resources
- Check security contexts are not weakened (non-root user, read-only root filesystem, dropped capabilities)
- Verify resource requests/limits are reasonable
- Ensure the single-instance constraint (`replicaCount: 1`) for the StatefulSet is preserved
- Validate that persistence settings (PVC, emptyDir, existing claims) work correctly

### Secrets and Security
- Never allow secrets or tokens to be hardcoded in templates or values
- Ensure secrets use `lookup` and `helm.sh/resource-policy: keep` to preserve values on upgrades
- Verify the `openclaw.validateSecrets` helper is not bypassed
- Check for sensitive data in ConfigMaps (should be in Secrets instead)

### Dockerfile
- Verify the image stays based on `node:24-slim`
- Ensure the non-root `vibe` user (UID/GID 1024) is preserved
- Check that `apt-get` layers are combined and caches cleaned
- Verify no secrets are baked into the image

### Values Consistency
- Changes to `values.yaml` defaults should be reflected across all preset files where appropriate
- New values should include documentation comments
- Schema changes in `values.schema.json` should match `values.yaml` structure

### CI/CD Workflows
- Workflow changes should not break existing lint/test/build pipelines
- Verify correct use of `actions/checkout`, pinned action versions, and appropriate permissions
- Ensure secrets are referenced via `${{ secrets.* }}`, never hardcoded
