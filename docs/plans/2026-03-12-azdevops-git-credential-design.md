# Azure DevOps Git Credential Helper

## Summary

Add an optional, default-enabled git credential helper that automatically configures Azure DevOps authentication using Azure CLI tokens. When enabled, the init script creates a credential helper script and configures git to use it for Azure DevOps domains.

## Motivation

Users frequently need to clone/push to Azure DevOps repositories from their openclaw containers. Currently they must manually configure git credentials each time. This feature automates the setup, requiring only `az login` before git operations work.

## Design

### Helm Values

```yaml
openclaw:
  git:
    azureDevOps:
      enabled: true  # default: on
```

When disabled, the init script skips all credential helper setup. No scripts or git config entries are created in the container.

### Implementation: Init Script + Env Var

The feature is controlled by passing `AZDEVOPS_GIT_CREDENTIAL_ENABLED` environment variable to the init container from the StatefulSet template. The init script checks this variable and conditionally sets up:

1. **Credential helper script** at `~/.git-credential-azdevops.sh` — fetches Azure DevOps tokens via `az account get-access-token`
2. **Git config entries** in `~/.gitconfig` — configures three domains to use the helper

### Credential Helper Script

```sh
#!/bin/sh
echo "username=azuredevops"
echo "password=$(az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv)"
```

### Git Config Entries

Configured for three Azure DevOps domains:
- `https://msazure.visualstudio.com` — useHttpPath, provider=generic, helper
- `https://supportability.visualstudio.com` — helper only
- `https://dev.azure.com` — useHttpPath, provider=generic, helper

### Execution Timing

Runs on **every restart** (outside the sentinel check), ensuring the credential helper is always present and up-to-date. This matches the existing pattern for skills re-sync.

### Prerequisites

- Azure CLI must be installed in the container image (already present)
- Users must run `az login` manually before git operations

## Files Changed

| File | Change |
|------|--------|
| `values.yaml` | Add `openclaw.git.azureDevOps.enabled: true` |
| `values.schema.json` | Add schema for `openclaw.git.azureDevOps` |
| `configs/init-home.sh` | Add git credential setup section |
| `templates/statefulset.yaml` | Add env var to init container |
