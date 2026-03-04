#!/usr/bin/env bash
set -euo pipefail

# Validate Cross-Tenancy Access
# Verifies that the scanning tenancy can access target tenancy resources

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[PASS]${NC} $1"; }
warn() { echo -e "${YELLOW}[SKIP]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }

SCANNING_COMPARTMENT="${SCANNING_COMPARTMENT_ID:?Set SCANNING_COMPARTMENT_ID}"
TARGET_COMPARTMENT="${TARGET_COMPARTMENT_ID:?Set TARGET_COMPARTMENT_ID}"
TARGET_TENANCY="${TARGET_TENANCY_ID:?Set TARGET_TENANCY_ID}"
REGION="${OCI_REGION:-us-ashburn-1}"
FUNCTION_ID="${FUNCTION_ID:-}"

echo "============================================"
echo "  Cross-Tenancy Validation"
echo "============================================"
echo "  Scanning Compartment: $SCANNING_COMPARTMENT"
echo "  Target Tenancy:       $TARGET_TENANCY"
echo "  Target Compartment:   $TARGET_COMPARTMENT"
echo "  Region:               $REGION"
echo "============================================"
echo ""

PASS=0
FAIL=0

# Test 1: List instances in target tenancy
echo "--- Test 1: List Instances (cross-tenancy) ---"
if oci compute instance list \
    --compartment-id "$TARGET_COMPARTMENT" \
    --region "$REGION" \
    --limit 1 \
    --query 'data[0].id' \
    --raw-output 2>/dev/null; then
  log "Can list instances in target tenancy"
  PASS=$((PASS + 1))
else
  fail "Cannot list instances in target tenancy"
  FAIL=$((FAIL + 1))
fi

# Test 2: List volume attachments in target tenancy
echo "--- Test 2: List Volume Attachments (cross-tenancy) ---"
if oci compute volume-attachment list \
    --compartment-id "$TARGET_COMPARTMENT" \
    --region "$REGION" \
    --limit 1 \
    --query 'data[0].id' \
    --raw-output 2>/dev/null; then
  log "Can list volume attachments in target tenancy"
  PASS=$((PASS + 1))
else
  fail "Cannot list volume attachments in target tenancy"
  FAIL=$((FAIL + 1))
fi

# Test 3: List boot volume attachments in target tenancy
echo "--- Test 3: List Boot Volume Attachments (cross-tenancy) ---"
if oci compute boot-volume-attachment list \
    --compartment-id "$TARGET_COMPARTMENT" \
    --availability-domain "$(oci iam availability-domain list --compartment-id "$TARGET_COMPARTMENT" --region "$REGION" --query 'data[0].name' --raw-output 2>/dev/null)" \
    --region "$REGION" \
    --limit 1 2>/dev/null; then
  log "Can list boot volume attachments in target tenancy"
  PASS=$((PASS + 1))
else
  fail "Cannot list boot volume attachments in target tenancy"
  FAIL=$((FAIL + 1))
fi

# Test 4: Verify NoSQL tables exist in scanning tenancy
echo "--- Test 4: NoSQL Tables ---"
TABLES=("snapshot_resource_inventory" "snapshot_scan_status" "snapshot_event_logs" "snapshot_discovery_task" "snapshot_app_config")
for table in "${TABLES[@]}"; do
  if oci nosql table get \
      --table-name-or-id "$table" \
      --compartment-id "$SCANNING_COMPARTMENT" \
      --query 'data.name' \
      --raw-output 2>/dev/null | grep -q "$table"; then
    log "NoSQL table exists: $table"
    PASS=$((PASS + 1))
  else
    fail "NoSQL table missing: $table"
    FAIL=$((FAIL + 1))
  fi
done

# Test 5: Verify queues exist
echo "--- Test 5: OCI Queues ---"
QUEUE_COUNT=$(oci queue queue list \
    --compartment-id "$SCANNING_COMPARTMENT" \
    --query 'data.items[?contains(display_name, `snapshot-`)].display_name | length(@)' \
    --raw-output 2>/dev/null || echo "0")
if [[ "$QUEUE_COUNT" -ge 6 ]]; then
  log "Found $QUEUE_COUNT snapshot queues (expected >=6)"
  PASS=$((PASS + 1))
else
  fail "Found $QUEUE_COUNT snapshot queues (expected >=6)"
  FAIL=$((FAIL + 1))
fi

# Test 6: Function invocation test (if FUNCTION_ID provided)
echo "--- Test 6: Function Invocation ---"
if [[ -n "$FUNCTION_ID" ]]; then
  RESULT=$(oci fn function invoke \
      --function-id "$FUNCTION_ID" \
      --body '{"service":"compute","operation":"listInstances","params":{"compartmentId":"'"$TARGET_COMPARTMENT"'"},"region":"'"$REGION"'"}' \
      --raw-output 2>/dev/null)
  if echo "$RESULT" | jq -e '.statusCode == 200' >/dev/null 2>&1; then
    log "Function successfully invoked cross-tenancy SDK operation"
    PASS=$((PASS + 1))
  else
    fail "Function invocation returned unexpected result"
    FAIL=$((FAIL + 1))
  fi
else
  warn "Skipping function test (set FUNCTION_ID to enable)"
fi

echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
