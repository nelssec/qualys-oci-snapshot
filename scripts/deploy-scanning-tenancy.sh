#!/usr/bin/env bash
set -euo pipefail

# Deploy Scanning Tenancy Infrastructure
# Usage: ./deploy-scanning-tenancy.sh [plan|apply|destroy]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TF_DIR="$PROJECT_ROOT/terraform/scanning-tenancy"

ACTION="${1:-plan}"

# Colors
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
  "TF_VAR_qflow_token"
  "TF_VAR_qflow_endpoint"
  "TF_VAR_ocir_registry"
  "TF_VAR_object_storage_namespace"
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    err "Required environment variable $var is not set"
    exit 1
  fi
done

log "Deploying Scanning Tenancy infrastructure..."
log "  Tenancy:     ${TF_VAR_tenancy_id}"
log "  Compartment: ${TF_VAR_compartment_id}"
log "  Region:      ${TF_VAR_region}"
log "  Action:      ${ACTION}"

# Build functions first (if applying)
if [[ "$ACTION" == "apply" ]]; then
  log "Building OCI Functions..."
  cd "$PROJECT_ROOT/functions"

  if [[ -f "package.json" ]]; then
    npm ci
    npx tsc
    log "TypeScript compilation complete"
  fi

  # Build and push Docker images
  REGISTRY="${TF_VAR_ocir_registry}"
  TAG="${TF_VAR_image_tag:-latest}"

  FUNCTIONS=(
    oci-sdk-wrapper data-formatter nosql-wrapper create-scan-status
    generate-scan-chunks fetch-inventory-chunks generate-scan-params
    app-config-store stack-cleanup image-cleanup discovery-worker
    discovery-scheduler image-discovery-scheduler event-task-scheduler
    scheduled-fn-check post-process-scan process-scan-files on-demand-scan
    download-to-storage update-function-code create-bucket qflow-api
    proxy-instance
  )

  for fn in "${FUNCTIONS[@]}"; do
    log "Building function: $fn"
    docker build -t "$REGISTRY/snapshot-scanner/$fn:$TAG" \
      -f "$PROJECT_ROOT/functions/$fn/Dockerfile" \
      "$PROJECT_ROOT/functions/" 2>/dev/null || {
        warn "Docker build failed for $fn - continuing (image may need to be built separately)"
      }
  done

  log "Pushing function images to OCIR..."
  for fn in "${FUNCTIONS[@]}"; do
    docker push "$REGISTRY/snapshot-scanner/$fn:$TAG" 2>/dev/null || {
      warn "Push failed for $fn - continuing"
    }
  done

  cd "$TF_DIR"
fi

# Terraform operations
cd "$TF_DIR"

log "Initializing Terraform..."
terraform init -upgrade

case "$ACTION" in
  plan)
    log "Running terraform plan..."
    terraform plan -out=tfplan
    log "Plan saved to tfplan. Run with 'apply' to execute."
    ;;
  apply)
    log "Running terraform apply..."
    terraform apply -auto-approve
    log "Scanning tenancy deployment complete!"

    # Output key values
    echo ""
    log "=== Deployment Outputs ==="
    terraform output -json | jq -r 'to_entries[] | "  \(.key): \(.value.value)"'
    ;;
  destroy)
    warn "Destroying scanning tenancy infrastructure..."
    read -p "Are you sure? (yes/no): " confirm
    if [[ "$confirm" == "yes" ]]; then
      terraform destroy -auto-approve
      log "Scanning tenancy infrastructure destroyed."
    else
      log "Destroy cancelled."
    fi
    ;;
  *)
    err "Unknown action: $ACTION. Use plan, apply, or destroy."
    exit 1
    ;;
esac
