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
