#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Azure setup script for OpenClaw Kubernetes
#
# Creates an AKS cluster and deploys OpenClaw with:
#   - AKS cluster with system node pool
#   - Azure File StorageClass (premium, correct UID/GID for vibe user)
#   - LiteLLM proxy (default: GitHub Copilot, configurable)
#   - Telegram bot integration (optional)
#   - Persistent storage for both OpenClaw and LiteLLM
#
# Usage:
#   # Minimal (GitHub Copilot, no Telegram):
#   ./scripts/azure-setup.sh
#
#   # With .env file (recommended):
#   cp .env.example .env && vi .env
#   ./scripts/azure-setup.sh
#
#   # With Telegram:
#   TELEGRAM_BOT_TOKEN=<token> ./scripts/azure-setup.sh
#
#   # With Anthropic:
#   LITELLM_PROVIDER=anthropic LITELLM_API_KEY=<key> LITELLM_MODEL=claude-sonnet-4-20250514 ./scripts/azure-setup.sh
#
#   # Custom cluster name and region:
#   CLUSTER_NAME=my-openclaw LOCATION=eastus ./scripts/azure-setup.sh
#
#   # Skip cluster creation (deploy to existing cluster):
#   SKIP_CLUSTER=true ./scripts/azure-setup.sh
#
# Configuration is loaded in this order (later overrides earlier):
#   1. .env file (in script dir or project root)
#   2. Environment variables
#
# Environment variables:
#   CLUSTER_NAME          AKS cluster name (default: openclaw)
#   RESOURCE_GROUP        Azure resource group (default: openclaw-rg)
#   LOCATION              Azure region (default: westus2)
#   SUBSCRIPTION          Azure subscription ID (default: current)
#   NODE_VM_SIZE          VM size for nodes (default: Standard_D4s_v3)
#   NODE_COUNT            Number of nodes (default: 1)
#   K8S_VERSION           Kubernetes version (default: latest stable)
#   SKIP_CLUSTER          Skip AKS creation, deploy to current context (default: false)
#   RELEASE_NAME          Helm release name (default: openclaw)
#   WORKLOAD_IDENTITY     Enable Azure Workload Identity (default: false)
#   WORKLOAD_IDENTITY_ROLE Role for the managed identity (default: Contributor)
#   WORKLOAD_IDENTITY_SCOPE Resource ID scope for role assignment (required if WORKLOAD_IDENTITY=true)
#   GATEWAY_TOKEN         Gateway auth token (auto-generated if empty)
#   TELEGRAM_BOT_TOKEN    Telegram bot token (optional)
#   LITELLM_PROVIDER      LiteLLM provider (default: github_copilot)
#   LITELLM_API_KEY       Provider API key (not needed for github_copilot)
#   LITELLM_API_BASE      Provider API base URL (optional)
#   LITELLM_MODEL         Model name (default: claude-opus-4.6)
#   EMBEDDING_PROVIDER    Embedding provider (default: openai)
#   EMBEDDING_API_KEY     Embedding API key (optional, enables memory search)
#   PERSISTENCE_SIZE      PVC size (default: 100Gi)
#   CHART_SOURCE          Helm chart source: "oci" or "local" (default: oci)
#   DRY_RUN               Print commands without executing (default: false)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Load .env file (if present) ─────────────────────────────────────────────
# .env is loaded first; env vars set before the script override .env values.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

load_env() {
  local envfile="$1"
  if [ -f "$envfile" ]; then
    # Read each line: skip comments and blank lines, export KEY=VALUE
    # Only set vars that aren't already set in the environment (env > .env)
    while IFS= read -r line || [ -n "$line" ]; do
      # Skip comments and blank lines
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      [[ -z "${line// }" ]] && continue
      # Extract key
      local key="${line%%=*}"
      key="${key// }"
      # Only set if not already in environment
      if [ -z "${!key+x}" ]; then
        export "$line"
      fi
    done < "$envfile"
  fi
}

# Check project root first, then script dir
if [ -f "$PROJECT_ROOT/.env" ]; then
  load_env "$PROJECT_ROOT/.env"
elif [ -f "$SCRIPT_DIR/.env" ]; then
  load_env "$SCRIPT_DIR/.env"
fi

# ── Configuration ────────────────────────────────────────────────────────────

CLUSTER_NAME="${CLUSTER_NAME:-openclaw}"
RESOURCE_GROUP="${RESOURCE_GROUP:-openclaw-rg}"
LOCATION="${LOCATION:-westus2}"
SUBSCRIPTION="${SUBSCRIPTION:-}"
NODE_VM_SIZE="${NODE_VM_SIZE:-Standard_D4s_v3}"
NODE_COUNT="${NODE_COUNT:-1}"
K8S_VERSION="${K8S_VERSION:-}"
SKIP_CLUSTER="${SKIP_CLUSTER:-false}"
WORKLOAD_IDENTITY="${WORKLOAD_IDENTITY:-false}"
WORKLOAD_IDENTITY_ROLE="${WORKLOAD_IDENTITY_ROLE:-Contributor}"
WORKLOAD_IDENTITY_SCOPE="${WORKLOAD_IDENTITY_SCOPE:-}"
NAMESPACE="openclaw"
RELEASE_NAME="${RELEASE_NAME:-openclaw}"

GATEWAY_TOKEN="${GATEWAY_TOKEN:-}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"

LITELLM_PROVIDER="${LITELLM_PROVIDER:-github_copilot}"
LITELLM_API_KEY="${LITELLM_API_KEY:-}"
LITELLM_API_BASE="${LITELLM_API_BASE:-}"
LITELLM_MODEL="${LITELLM_MODEL:-claude-opus-4.6}"

EMBEDDING_PROVIDER="${EMBEDDING_PROVIDER:-openai}"
EMBEDDING_API_KEY="${EMBEDDING_API_KEY:-}"

PERSISTENCE_SIZE="${PERSISTENCE_SIZE:-100Gi}"
CHART_SOURCE="${CHART_SOURCE:-oci}"
DRY_RUN="${DRY_RUN:-false}"

# ── Helpers ──────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*" >&2; }
info() { echo -e "${CYAN}[i]${NC} $*"; }

run() {
  if [ "$DRY_RUN" = "true" ]; then
    info "DRY RUN: $*"
  else
    "$@"
  fi
}

check_tool() {
  if ! command -v "$1" &>/dev/null; then
    err "$1 is required but not installed."
    case "$1" in
      az)   echo "  Install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" ;;
      helm) echo "  Install: https://helm.sh/docs/intro/install/" ;;
      kubectl) echo "  Install: https://kubernetes.io/docs/tasks/tools/" ;;
      openssl) echo "  Install: https://www.openssl.org/ (or install via package manager)" ;;
    esac
    exit 1
  fi
}

# ── Preflight ────────────────────────────────────────────────────────────────

log "Checking prerequisites..."
check_tool helm
check_tool kubectl
check_tool openssl

if [ "$SKIP_CLUSTER" != "true" ]; then
  check_tool az

  # Verify Azure login
  if ! az account show &>/dev/null; then
    err "Not logged in to Azure. Run: az login"
    exit 1
  fi

  # Set subscription if specified
  if [ -n "$SUBSCRIPTION" ]; then
    run az account set --subscription "$SUBSCRIPTION"
  fi
  SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
  info "Azure subscription: $SUBSCRIPTION_NAME"
fi

# Generate gateway token if not provided
if [ -z "$GATEWAY_TOKEN" ]; then
  GATEWAY_TOKEN=$(openssl rand -hex 32)
  info "Generated gateway token (save this): $GATEWAY_TOKEN"
fi

# ── Step 1: Create AKS cluster ──────────────────────────────────────────────

if [ "$SKIP_CLUSTER" != "true" ]; then
  # Check if resource group already exists
  RG_EXISTS=$(az group exists --name "$RESOURCE_GROUP" 2>/dev/null || echo "false")
  if [ "$RG_EXISTS" = "true" ]; then
    RG_LOCATION=$(az group show --name "$RESOURCE_GROUP" --query location -o tsv)
    info "Resource group $RESOURCE_GROUP already exists (location: $RG_LOCATION)"
    LOCATION="$RG_LOCATION"
  else
    log "Creating resource group: $RESOURCE_GROUP in $LOCATION..."
    run az group create \
      --name "$RESOURCE_GROUP" \
      --location "$LOCATION" \
      --output none
  fi

  # Resolve k8s version
  K8S_VERSION_FLAG=""
  if [ -n "$K8S_VERSION" ]; then
    K8S_VERSION_FLAG="--kubernetes-version $K8S_VERSION"
  fi

  log "Creating AKS cluster: $CLUSTER_NAME ($NODE_COUNT x $NODE_VM_SIZE)..."
  WI_FLAGS=""
  if [ "$WORKLOAD_IDENTITY" = "true" ]; then
    WI_FLAGS="--enable-oidc-issuer --enable-workload-identity"
    info "Workload identity enabled on cluster"
  fi

  run az aks create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CLUSTER_NAME" \
    --node-count "$NODE_COUNT" \
    --node-vm-size "$NODE_VM_SIZE" \
    $K8S_VERSION_FLAG \
    $WI_FLAGS \
    --enable-managed-identity \
    --generate-ssh-keys \
    --output none

  log "Getting AKS credentials..."
  run az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CLUSTER_NAME" \
    --overwrite-existing

  # ── Step 1b: Set up Workload Identity ──────────────────────────────────────

  if [ "$WORKLOAD_IDENTITY" = "true" ]; then
    IDENTITY_NAME="${CLUSTER_NAME}-identity"

    log "Creating managed identity: $IDENTITY_NAME..."
    run az identity create \
      --resource-group "$RESOURCE_GROUP" \
      --name "$IDENTITY_NAME" \
      --location "$LOCATION" \
      --output none

    if [ "$DRY_RUN" = "true" ]; then
      IDENTITY_CLIENT_ID="<dry-run-client-id>"
      IDENTITY_PRINCIPAL_ID="<dry-run-principal-id>"
      OIDC_ISSUER="<dry-run-oidc-issuer>"
    else
      IDENTITY_CLIENT_ID=$(az identity show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$IDENTITY_NAME" \
        --query clientId -o tsv)
      IDENTITY_PRINCIPAL_ID=$(az identity show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$IDENTITY_NAME" \
        --query principalId -o tsv)

      # Get AKS OIDC issuer URL
      OIDC_ISSUER=$(az aks show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER_NAME" \
        --query oidcIssuerProfile.issuerUrl -o tsv)
    fi
    info "Managed identity client ID: $IDENTITY_CLIENT_ID"
    info "OIDC issuer: $OIDC_ISSUER"

    # Create federated credential linking K8s SA to managed identity
    log "Creating federated credential..."
    FEDERATION_NAME="${CLUSTER_NAME}-openclaw-federation"
    # Determine the service account name Helm will create
    SA_NAME="${RELEASE_NAME}"  # Helm default: release name
    run az identity federated-credential create \
      --name "$FEDERATION_NAME" \
      --identity-name "$IDENTITY_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --issuer "$OIDC_ISSUER" \
      --subject "system:serviceaccount:${NAMESPACE}:${SA_NAME}" \
      --audiences "api://AzureADTokenExchange" \
      --output none

    # Assign role on the target scope
    if [ -n "$WORKLOAD_IDENTITY_SCOPE" ]; then
      log "Assigning role '$WORKLOAD_IDENTITY_ROLE' on scope..."
      info "Scope: $WORKLOAD_IDENTITY_SCOPE"
      run az role assignment create \
        --assignee-object-id "$IDENTITY_PRINCIPAL_ID" \
        --assignee-principal-type ServicePrincipal \
        --role "$WORKLOAD_IDENTITY_ROLE" \
        --scope "$WORKLOAD_IDENTITY_SCOPE" \
        --output none
    else
      warn "WORKLOAD_IDENTITY_SCOPE not set — skipping role assignment"
      warn "You must assign roles manually: az role assignment create --assignee-object-id <principal-id> --assignee-principal-type ServicePrincipal --role <role> --scope <scope>"
    fi
  fi
else
  info "Skipping cluster creation (SKIP_CLUSTER=true)"
  info "Using current kubectl context: $(kubectl config current-context)"
fi

# ── Step 2: Create Azure File StorageClass ───────────────────────────────────

log "Creating Azure File StorageClass (azurefile-openclaw)..."
run kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-openclaw
provisioner: file.csi.azure.com
allowVolumeExpansion: true
parameters:
  skuName: Premium_LRS
reclaimPolicy: Delete
volumeBindingMode: Immediate
mountOptions:
  - dir_mode=0755
  - file_mode=0755
  - uid=1024
  - gid=1024
  - mfsymlinks
  - cache=strict
  - nosharesock
  - actimeo=30
  - nobrl
EOF

log "Creating Azure File StorageClass for LiteLLM (azurefile-litellm)..."
run kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-litellm
provisioner: file.csi.azure.com
allowVolumeExpansion: true
parameters:
  skuName: Premium_LRS
reclaimPolicy: Delete
volumeBindingMode: Immediate
mountOptions:
  - dir_mode=0755
  - file_mode=0755
  - uid=1000
  - gid=1000
  - mfsymlinks
  - cache=strict
  - nosharesock
  - actimeo=30
  - nobrl
EOF

# ── Step 3: Build Helm values ────────────────────────────────────────────────

log "Building Helm install command..."

HELM_SETS=(
  --create-namespace
  --namespace "$NAMESPACE"
  --set "secrets.openclawGatewayToken=$GATEWAY_TOKEN"
  --set "persistence.storageClass=azurefile-openclaw"
  --set "persistence.accessMode=ReadWriteMany"
  --set "persistence.size=$PERSISTENCE_SIZE"
  --set "litellm.persistence.storageClass=azurefile-litellm"
  --set "litellm.persistence.accessMode=ReadWriteMany"
  --set "litellm.model=$LITELLM_MODEL"
  --set "litellm.secrets.provider=$LITELLM_PROVIDER"
)

# Workload Identity
if [ "$WORKLOAD_IDENTITY" = "true" ] && [ -n "${IDENTITY_CLIENT_ID:-}" ]; then
  HELM_SETS+=(
    --set "azureWorkloadIdentity.enabled=true"
    --set "azureWorkloadIdentity.clientId=$IDENTITY_CLIENT_ID"
  )
  info "Workload identity configured (clientId: $IDENTITY_CLIENT_ID)"
fi

# Telegram
if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
  HELM_SETS+=(--set "secrets.telegramBotToken=$TELEGRAM_BOT_TOKEN")
  info "Telegram bot enabled"
fi

# LiteLLM provider credentials
if [ -n "$LITELLM_API_KEY" ]; then
  HELM_SETS+=(--set "litellm.secrets.apiKey=$LITELLM_API_KEY")
fi
if [ -n "$LITELLM_API_BASE" ]; then
  HELM_SETS+=(--set "litellm.secrets.apiBase=$LITELLM_API_BASE")
fi

# Embedding / memory search
if [ -n "$EMBEDDING_API_KEY" ]; then
  HELM_SETS+=(
    --set "litellm.secrets.embeddingProvider=$EMBEDDING_PROVIDER"
    --set "litellm.secrets.embeddingApiKey=$EMBEDDING_API_KEY"
  )
  info "Memory search enabled (embedding provider: $EMBEDDING_PROVIDER)"
fi

# ── Step 4: Install chart ────────────────────────────────────────────────────

if [ "$CHART_SOURCE" = "local" ]; then
  info "Installing from local chart: $PROJECT_ROOT"
  run helm upgrade --install "$RELEASE_NAME" "$PROJECT_ROOT" "${HELM_SETS[@]}"
else
  info "Installing from OCI registry"
  run helm upgrade --install "$RELEASE_NAME" oci://ghcr.io/feiskyer/openclaw-kubernetes/openclaw "${HELM_SETS[@]}"
fi

# ── Step 5: Wait for rollout ─────────────────────────────────────────────────

if [ "$DRY_RUN" != "true" ]; then
  log "Waiting for OpenClaw pod to be ready..."
  kubectl -n "$NAMESPACE" rollout status statefulset/openclaw --timeout=300s

  log "Waiting for LiteLLM deployment to be ready..."
  kubectl -n "$NAMESPACE" rollout status deployment/openclaw-litellm --timeout=120s 2>/dev/null || true
fi

# ── Step 6: Print access info ────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log "OpenClaw deployed successfully!"
echo ""
info "Gateway token: $GATEWAY_TOKEN"
echo ""
info "Access the portal (port-forward):"
echo "  kubectl -n $NAMESPACE port-forward openclaw-0 18789:18789"
echo "  Open: http://localhost:18789/?token=$GATEWAY_TOKEN"
echo ""
info "Access Chrome desktop (noVNC):"
echo "  kubectl -n $NAMESPACE port-forward openclaw-0 6080:6080"
echo "  Open: http://localhost:6080/vnc.html"
echo ""
info "Check pod status:"
echo "  kubectl -n $NAMESPACE get pods"
echo "  kubectl -n $NAMESPACE logs openclaw-0 -f"
echo ""
if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
  info "Telegram bot is configured. Message your bot to start chatting."
  echo ""
fi
info "To uninstall:"
echo "  helm uninstall openclaw -n $NAMESPACE"
if [ "$SKIP_CLUSTER" != "true" ]; then
  echo "  az group delete --name $RESOURCE_GROUP --yes --no-wait"
fi
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
