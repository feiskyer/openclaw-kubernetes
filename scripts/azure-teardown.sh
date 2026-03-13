#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Azure teardown script for OpenClaw Kubernetes
#
# Removes OpenClaw deployment and optionally the AKS cluster + resource group.
#
# Usage:
#   ./scripts/azure-teardown.sh                    # Uninstall chart only
#   DELETE_CLUSTER=true ./scripts/azure-teardown.sh # Also delete AKS + RG
#
# Environment variables:
#   RESOURCE_GROUP   Azure resource group (default: openclaw-rg)
#   CLUSTER_NAME     AKS cluster name (default: openclaw)
#   DELETE_CLUSTER   Also delete AKS cluster and resource group (default: false)
#   DRY_RUN          Print commands without executing (default: false)
# ─────────────────────────────────────────────────────────────────────────────
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

RESOURCE_GROUP="${RESOURCE_GROUP:-openclaw-rg}"
CLUSTER_NAME="${CLUSTER_NAME:-openclaw}"
SUBSCRIPTION="${SUBSCRIPTION:-}"
NAMESPACE="openclaw"
RELEASE_NAME="${RELEASE_NAME:-openclaw}"
DELETE_CLUSTER="${DELETE_CLUSTER:-false}"
DRY_RUN="${DRY_RUN:-false}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
info() { echo -e "${CYAN}[i]${NC} $*"; }

run() {
  if [ "$DRY_RUN" = "true" ]; then
    info "DRY RUN: $*"
  else
    "$@"
  fi
}

# ── Set subscription ────────────────────────────────────────────────────────

if [ -n "$SUBSCRIPTION" ]; then
  run az account set --subscription "$SUBSCRIPTION"
fi

# ── Step 1: Uninstall Helm release ──────────────────────────────────────────

log "Uninstalling OpenClaw Helm release..."
run helm uninstall "$RELEASE_NAME" --namespace "$NAMESPACE" 2>/dev/null || warn "Release '$RELEASE_NAME' not found (already uninstalled?)"

# ── Step 2: Clean up namespace ──────────────────────────────────────────────

log "Checking for remaining PVCs in namespace $NAMESPACE..."
if [ "$DRY_RUN" != "true" ]; then
  PVCS=$(kubectl -n "$NAMESPACE" get pvc -o name 2>/dev/null || true)
  if [ -n "$PVCS" ]; then
    warn "Found PVCs that were not deleted by Helm (retainPolicy: Retain):"
    echo "$PVCS"
    echo ""
    read -p "Delete these PVCs? Data will be lost. (y/N) " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      kubectl -n "$NAMESPACE" delete pvc --all
      log "PVCs deleted"
    else
      info "PVCs retained. Delete manually when ready:"
      echo "  kubectl -n $NAMESPACE delete pvc --all"
    fi
  fi
fi

# Delete StorageClasses
log "Deleting Azure File StorageClasses..."
run kubectl delete storageclass azurefile-openclaw 2>/dev/null || true
run kubectl delete storageclass azurefile-litellm 2>/dev/null || true

# Delete namespace if empty
if [ "$DRY_RUN" != "true" ]; then
  REMAINING=$(kubectl -n "$NAMESPACE" get all -o name 2>/dev/null || true)
  if [ -z "$REMAINING" ]; then
    log "Deleting empty namespace $NAMESPACE..."
    run kubectl delete namespace "$NAMESPACE" 2>/dev/null || true
  else
    warn "Namespace $NAMESPACE still has resources, not deleting"
  fi
fi

# ── Step 3: Clean up Workload Identity resources ────────────────────────────

IDENTITY_NAME="${CLUSTER_NAME}-identity"
if az identity show --resource-group "$RESOURCE_GROUP" --name "$IDENTITY_NAME" &>/dev/null; then
  log "Cleaning up workload identity resources..."

  # Delete federated credential
  FEDERATION_NAME="${CLUSTER_NAME}-openclaw-federation"
  run az identity federated-credential delete \
    --name "$FEDERATION_NAME" \
    --identity-name "$IDENTITY_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --yes 2>/dev/null || true

  # Delete managed identity (also removes its role assignments)
  run az identity delete \
    --resource-group "$RESOURCE_GROUP" \
    --name "$IDENTITY_NAME" 2>/dev/null || true
  log "Workload identity cleaned up"
fi

# ── Step 4: Optionally delete AKS cluster ───────────────────────────────────

if [ "$DELETE_CLUSTER" = "true" ]; then
  echo ""
  warn "DELETE_CLUSTER=true — will delete AKS cluster '$CLUSTER_NAME' and resource group '$RESOURCE_GROUP'"
  if [ "$DRY_RUN" != "true" ]; then
    read -p "Are you sure? This is irreversible. (y/N) " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      log "Deleting resource group $RESOURCE_GROUP (async)..."
      run az group delete --name "$RESOURCE_GROUP" --yes --no-wait
      log "Resource group deletion started (runs in background)"
    else
      info "Cancelled cluster deletion"
    fi
  else
    run az group delete --name "$RESOURCE_GROUP" --yes --no-wait
  fi
else
  echo ""
  info "Cluster retained. To also delete the AKS cluster:"
  echo "  DELETE_CLUSTER=true ./scripts/azure-teardown.sh"
  echo "  # or manually:"
  echo "  az group delete --name $RESOURCE_GROUP --yes --no-wait"
fi

echo ""
log "Done."
