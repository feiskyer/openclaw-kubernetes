# Azure DevOps Git Credential Helper — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an optional, default-enabled init-time setup that configures git credential helpers for Azure DevOps domains using Azure CLI tokens.

**Architecture:** A Helm values toggle (`openclaw.git.azureDevOps.enabled`) controls an environment variable passed to the init container. The init script conditionally creates a credential helper script and git config entries on the PVC, running on every restart.

**Tech Stack:** Helm chart templates (Go templates), shell script, git config

---

### Task 1: Add Helm values toggle

**Files:**
- Modify: `values.yaml:362` (after `openclaw.acpx.agents` block, before `openclaw.skills`)

**Step 1: Add the git configuration block**

Insert this block at `values.yaml` line 362, between the `acpx.agents` section and the `skills` section:

```yaml
  # -- Git credential configuration for Azure DevOps.
  # When enabled, the init container installs a credential helper script
  # that fetches Azure DevOps tokens via Azure CLI (`az account get-access-token`).
  # Users must run `az login` before git operations will work.
  git:
    azureDevOps:
      # -- Enable Azure DevOps git credential helper
      enabled: true
```

**Step 2: Commit**

```bash
git add values.yaml
git commit -m "feat: add openclaw.git.azureDevOps.enabled helm value"
```

---

### Task 2: Add JSON schema for the new value

**Files:**
- Modify: `values.schema.json:487` (inside `openclaw.properties`, after `dmAccess`)

**Step 1: Add the git schema block**

Insert this after the `dmAccess` property (line 486), before the closing `}` of `openclaw.properties`:

```json
        "git": {
          "type": "object",
          "description": "Git credential configuration",
          "properties": {
            "azureDevOps": {
              "type": "object",
              "description": "Azure DevOps git credential helper configuration",
              "properties": {
                "enabled": {
                  "type": "boolean",
                  "description": "Enable Azure DevOps git credential helper (uses az CLI for tokens)",
                  "default": true
                }
              }
            }
          }
        }
```

**Step 2: Commit**

```bash
git add values.schema.json
git commit -m "feat: add JSON schema for openclaw.git.azureDevOps"
```

---

### Task 3: Add env var to init container in StatefulSet template

**Files:**
- Modify: `templates/statefulset.yaml:47` (init container definition)

**Step 1: Add env section to init container**

The init container currently has no `env` block. Add one after the `command` line (line 47) and before `volumeMounts` (line 48):

```yaml
          {{- if dig "git" "azureDevOps" "enabled" true .Values.openclaw }}
          env:
            - name: AZDEVOPS_GIT_CREDENTIAL_ENABLED
              value: "true"
          {{- end }}
```

Note: `dig` with default `true` ensures backward compatibility — if the value isn't set at all, it defaults to enabled.

**Step 2: Commit**

```bash
git add templates/statefulset.yaml
git commit -m "feat: pass AZDEVOPS_GIT_CREDENTIAL_ENABLED env to init container"
```

---

### Task 4: Add git credential setup to init-home.sh

**Files:**
- Modify: `configs/init-home.sh`

**Step 1: Add the setup function**

The init script has two paths:
1. **Restart path** (sentinel exists): lines 7-18, syncs skills then `exit 0`
2. **First run path** (no sentinel): lines 21-41

We need to add the git credential setup **before the exit in the restart path** (so it runs on every restart) AND **after the first-run seed** (so it runs on first init too).

The cleanest approach: extract a function and call it in both paths.

Replace the entire `configs/init-home.sh` with:

```sh
#!/bin/sh
set -e

SENTINEL="/home-data/.openclaw/.initialized"

# Setup Azure DevOps git credential helper (idempotent, runs on every start)
setup_azdevops_git_credential() {
  if [ "$AZDEVOPS_GIT_CREDENTIAL_ENABLED" != "true" ]; then
    return
  fi

  # Create credential helper script
  cat > /home-data/.git-credential-azdevops.sh << 'SCRIPT'
#!/bin/sh
# Git credential helper that fetches Azure DevOps tokens via Azure CLI
echo "username=azuredevops"
echo "password=$(az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv)"
SCRIPT
  chmod +x /home-data/.git-credential-azdevops.sh
  chown 1024:1024 /home-data/.git-credential-azdevops.sh

  # Configure git credential helpers for Azure DevOps domains
  # Note: helper path uses /home/vibe/ (runtime mount), not /home-data/ (init mount)
  GITCONFIG="/home-data/.gitconfig"
  git config --file "$GITCONFIG" credential.https://msazure.visualstudio.com.useHttpPath true
  git config --file "$GITCONFIG" credential.https://msazure.visualstudio.com.provider generic
  git config --file "$GITCONFIG" credential.https://msazure.visualstudio.com.helper "/home/vibe/.git-credential-azdevops.sh"
  git config --file "$GITCONFIG" credential.https://supportability.visualstudio.com.helper "/home/vibe/.git-credential-azdevops.sh"
  git config --file "$GITCONFIG" credential.https://dev.azure.com.useHttpPath true
  git config --file "$GITCONFIG" credential.https://dev.azure.com.provider generic
  git config --file "$GITCONFIG" credential.https://dev.azure.com.helper "/home/vibe/.git-credential-azdevops.sh"
  chown 1024:1024 "$GITCONFIG"
}

# Fast restart path: sync new built-in skills from image, then exit
if [ -f "$SENTINEL" ]; then
  if [ -d /home/vibe/.openclaw/skills ]; then
    mkdir -p /home-data/.openclaw/skills
    for skill in /home/vibe/.openclaw/skills/*/; do
      skill_name=$(basename "$skill")
      if [ ! -d "/home-data/.openclaw/skills/$skill_name" ]; then
        cp -r "$skill" "/home-data/.openclaw/skills/$skill_name"
        chown -R 1024:1024 "/home-data/.openclaw/skills/$skill_name"
      fi
    done
  fi
  setup_azdevops_git_credential
  exit 0
fi

# First run: seed /home/vibe skeleton to PVC
if [ -z "$(ls -A /home-data 2>/dev/null)" ] || [ ! -d /home-data/.openclaw ]; then
  cp -r /home/vibe/. /home-data/
fi

# Seed configs from ConfigMap (skip if already present)
mkdir -p /home-data/.openclaw /home-data/.codex /home-data/.claude /home-data/.acpx
[ -f /etc/openclaw/openclaw.json ] && [ ! -f /home-data/.openclaw/openclaw.json ] && \
  cp /etc/openclaw/openclaw.json /home-data/.openclaw/openclaw.json
[ -f /etc/openclaw/codex-config.toml ] && [ ! -f /home-data/.codex/config.toml ] && \
  cp /etc/openclaw/codex-config.toml /home-data/.codex/config.toml
[ -f /etc/openclaw/claude-settings.json ] && [ ! -f /home-data/.claude/settings.json ] && \
  cp /etc/openclaw/claude-settings.json /home-data/.claude/settings.json
[ -f /etc/openclaw/acpx-config.json ] && [ ! -f /home-data/.acpx/config.json ] && \
  cp /etc/openclaw/acpx-config.json /home-data/.acpx/config.json

# Setup git credential helper
setup_azdevops_git_credential

# Fix ownership (only on first run)
chown -R 1024:1024 /home-data

# Mark as initialized — subsequent restarts skip everything
touch "$SENTINEL"
```

**Step 2: Commit**

```bash
git add configs/init-home.sh
git commit -m "feat: add Azure DevOps git credential helper to init script"
```

---

### Task 5: Verify with helm template

**Step 1: Run helm template to verify rendering**

```bash
cd /go/openclaw-kubernetes

# Default (enabled) — init container should have AZDEVOPS_GIT_CREDENTIAL_ENABLED env
helm template test . --set secrets.openclawGatewayToken=test 2>/dev/null | grep -A5 "AZDEVOPS"

# Disabled — env var should NOT appear
helm template test . --set secrets.openclawGatewayToken=test --set openclaw.git.azureDevOps.enabled=false 2>/dev/null | grep -A5 "AZDEVOPS"
```

Expected:
- First command: shows `AZDEVOPS_GIT_CREDENTIAL_ENABLED` with value `"true"`
- Second command: no output (env var not present)

**Step 2: Verify init-home.sh content is included in ConfigMap**

```bash
helm template test . --set secrets.openclawGatewayToken=test 2>/dev/null | grep -A3 "setup_azdevops_git_credential"
```

Expected: shows the function call in the rendered ConfigMap

**Step 3: Commit all changes together if not already committed**

```bash
git add -A
git commit -m "feat: Azure DevOps git credential helper

Add optional init-time git credential configuration for Azure DevOps.
Controlled by openclaw.git.azureDevOps.enabled (default: true).
Creates credential helper script and git config for three ADO domains."
```
