#!/bin/sh
set -e

SENTINEL="/home-data/.openclaw/.initialized"

# Skip entirely if already initialized — fast restart path
if [ -f "$SENTINEL" ]; then
  exit 0
fi

# First run: seed /home/vibe skeleton to PVC
if [ -z "$(ls -A /home-data 2>/dev/null)" ] || [ ! -d /home-data/.openclaw ]; then
  cp -r /home/vibe/. /home-data/
fi

# Seed configs from ConfigMap (skip if already present)
mkdir -p /home-data/.openclaw /home-data/.codex /home-data/.claude
[ -f /etc/openclaw/openclaw.json ] && [ ! -f /home-data/.openclaw/openclaw.json ] && \
  cp /etc/openclaw/openclaw.json /home-data/.openclaw/openclaw.json
[ -f /etc/openclaw/codex-config.toml ] && [ ! -f /home-data/.codex/config.toml ] && \
  cp /etc/openclaw/codex-config.toml /home-data/.codex/config.toml
[ -f /etc/openclaw/claude-settings.json ] && [ ! -f /home-data/.claude/settings.json ] && \
  cp /etc/openclaw/claude-settings.json /home-data/.claude/settings.json

# Fix ownership (only on first run)
chown -R 1024:1024 /home-data

# Mark as initialized — subsequent restarts skip everything
touch "$SENTINEL"
