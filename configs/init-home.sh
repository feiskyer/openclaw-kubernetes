#!/bin/sh
set -e

FIRST_RUN=false
# Seed /home/vibe to PVC on first run
if [ -z "$(ls -A /home-data 2>/dev/null)" ]; then
  cp -r /home/vibe/. /home-data/
  FIRST_RUN=true
fi

# Seed configs from ConfigMap (skip if already present)
mkdir -p /home-data/.openclaw /home-data/.codex /home-data/.claude
[ -f /etc/openclaw/openclaw.json ] && [ ! -f /home-data/.openclaw/openclaw.json ] && \
  cp /etc/openclaw/openclaw.json /home-data/.openclaw/openclaw.json
[ -f /etc/openclaw/codex-config.toml ] && [ ! -f /home-data/.codex/config.toml ] && \
  cp /etc/openclaw/codex-config.toml /home-data/.codex/config.toml
[ -f /etc/openclaw/claude-settings.json ] && [ ! -f /home-data/.claude/settings.json ] && \
  cp /etc/openclaw/claude-settings.json /home-data/.claude/settings.json

# Fix ownership — full recursive only on first run
if [ "$FIRST_RUN" = true ]; then
  chown -R 1024:1024 /home-data
fi
