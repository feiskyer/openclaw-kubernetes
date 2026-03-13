#!/usr/bin/env bash
# Port-forward OpenClaw (18789) and noVNC (6080) from the cluster.
# Ctrl+C to stop both.
set -euo pipefail

# ── Load .env file (if present) ─────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

load_env() {
  local envfile="$1"
  if [ -f "$envfile" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      [[ -z "${line// }" ]] && continue
      local key="${line%%=*}"
      key="${key// }"
      if [ -z "${!key+x}" ]; then
        export "$line"
      fi
    done < "$envfile"
  fi
}

if [ -f "$PROJECT_ROOT/.env" ]; then
  load_env "$PROJECT_ROOT/.env"
elif [ -f "$SCRIPT_DIR/.env" ]; then
  load_env "$SCRIPT_DIR/.env"
fi

NAMESPACE="${NAMESPACE:-openclaw}"
POD="${POD:-openclaw-0}"

# Track background PIDs and kill only those on exit
PIDS=()
cleanup() {
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT

echo "Forwarding OpenClaw → http://localhost:18789"
echo "Forwarding noVNC    → http://localhost:6080/vnc.html"
echo ""
echo "Press Ctrl+C to stop."
echo ""

kubectl -n "$NAMESPACE" port-forward "$POD" 18789:18789 &
PIDS+=($!)
kubectl -n "$NAMESPACE" port-forward "$POD" 6080:6080 &
PIDS+=($!)

wait
