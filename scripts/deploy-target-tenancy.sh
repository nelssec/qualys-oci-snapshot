#!/usr/bin/env bash
set -euo pipefail

# Deploy Target Tenancy Infrastructure
# Usage: ./deploy-target-tenancy.sh [plan|apply|destroy]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TF_DIR="$PROJECT_ROOT/terraform/target-tenancy"

ACTION="${1:-plan}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; }

# Validate required environment variables
required_vars=(
  "TF_VAR_tenancy_id"
  "TF_VAR_compartment_id"
  "TF_VAR_region"
  "TF_VAR_scanning_tenancy_id"
  "TF_VAR_scanning_dynamic_group_id"
  "TF_VAR_scanning_api_gateway_endpoint"
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    err "Required environment variable $var is not set"
    exit 1
  fi
done

log "Deploying Target Tenancy infrastructure..."
log "  Target Tenancy:   ${TF_VAR_tenancy_id}"
log "  Scanning Tenancy: ${TF_VAR_scanning_tenancy_id}"
log "  Region:           ${TF_VAR_region}"
log "  Action:           ${ACTION}"

# Build event-forwarder function if applying
if [[ "$ACTION" == "apply" && -n "${TF_VAR_event_forwarder_ocir_image:-}" ]]; then
  log "Building event-forwarder function..."
  cd "$PROJECT_ROOT/functions"
  docker build -t "${TF_VAR_event_forwarder_ocir_image}" \
    -f event-forwarder/Dockerfile . 2>/dev/null || {
      warn "Docker build failed for event-forwarder"
    }
  docker push "${TF_VAR_event_forwarder_ocir_image}" 2>/dev/null || {
    warn "Push failed for event-forwarder"
  }
  cd "$TF_DIR"
fi

cd "$TF_DIR"

log "Initializing Terraform..."
terraform init -upgrade

case "$ACTION" in
  plan)
    terraform plan -out=tfplan
    log "Plan saved. Run with 'apply' to execute."
    ;;
  apply)
    terraform apply -auto-approve
    log "Target tenancy deployment complete!"
    echo ""
    log "=== Deployment Outputs ==="
    terraform output -json | jq -r 'to_entries[] | "  \(.key): \(.value.value)"'
    ;;
  destroy)
    warn "Destroying target tenancy infrastructure..."
    read -p "Are you sure? (yes/no): " confirm
    if [[ "$confirm" == "yes" ]]; then
      terraform destroy -auto-approve
      log "Target tenancy infrastructure destroyed."
    else
      log "Destroy cancelled."
    fi
    ;;
  *)
    err "Unknown action: $ACTION"
    exit 1
    ;;
esac
