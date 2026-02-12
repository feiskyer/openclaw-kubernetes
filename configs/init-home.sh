#!/bin/sh
set -e

# Seed /home/vibe to PVC on first run
if [ -z "$(ls -A /home-data 2>/dev/null)" ]; then
  cp -r /home/vibe/. /home-data/
fi

# Seed configs from ConfigMap
mkdir -p /home-data/.openclaw /home-data/.codex /home-data/.claude
[ -f /etc/openclaw/openclaw.json ] && [ ! -f /home-data/.openclaw/openclaw.json ] && \
  cp /etc/openclaw/openclaw.json /home-data/.openclaw/openclaw.json
[ -f /etc/openclaw/codex-config.toml ] && \
  cp /etc/openclaw/codex-config.toml /home-data/.codex/config.toml
[ -f /etc/openclaw/claude-settings.json ] && \
  cp /etc/openclaw/claude-settings.json /home-data/.claude/settings.json

# Fix ownership to vibe:vibe (1024:1024)
chown -R 1024:1024 /home-data
