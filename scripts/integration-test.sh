#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Integration Test - Simulates qflow orchestration of the full scan pipeline
#
# Exercises each function in sequence via `oci fn function invoke`, verifying
# NoSQL state and OCI resources at each step. No qflow needed — this script
# acts as the orchestrator.
#
# Prerequisites:
#   - Scanning tenancy deployed (terraform apply)
#   - Target tenancy deployed (terraform apply)
#   - At least one running compute instance in the target tenancy
#   - OCI CLI configured with appropriate permissions
#   - jq installed
#
# Usage:
#   export SCANNING_COMPARTMENT_ID="ocid1.compartment.oc1..xxx"
#   export TARGET_TENANCY_ID="ocid1.tenancy.oc1..xxx"
#   export TARGET_COMPARTMENT_ID="ocid1.compartment.oc1..xxx"
#   export OCI_REGION="us-ashburn-1"
#   ./scripts/integration-test.sh [--step N] [--dry-run] [--skip-cleanup]
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${GREEN}[PASS]${NC}  $1"; }
fail() { echo -e "${RED}[FAIL]${NC}  $1"; FAILURES=$((FAILURES + 1)); }
info() { echo -e "${CYAN}[INFO]${NC}  $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
step() { echo -e "\n${BOLD}=== Step $1: $2 ===${NC}"; }

# --- Required env vars ---
SCANNING_COMPARTMENT="${SCANNING_COMPARTMENT_ID:?Set SCANNING_COMPARTMENT_ID}"
TARGET_TENANCY="${TARGET_TENANCY_ID:?Set TARGET_TENANCY_ID}"
TARGET_COMPARTMENT="${TARGET_COMPARTMENT_ID:?Set TARGET_COMPARTMENT_ID}"
REGION="${OCI_REGION:-us-ashburn-1}"

# --- Optional env vars ---
API_GATEWAY_ENDPOINT="${API_GATEWAY_ENDPOINT:-}"
SCANNER_IMAGE_ID="${SCANNER_IMAGE_ID:-}"
OS_NAMESPACE="${OBJECT_STORAGE_NAMESPACE:-}"

# --- Parse args ---
START_STEP=0
DRY_RUN=false
SKIP_CLEANUP=false
for arg in "$@"; do
  case "$arg" in
    --step)    shift; START_STEP="${1:-0}"; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --skip-cleanup) SKIP_CLEANUP=true; shift ;;
  esac
done

FAILURES=0
PASS=0
TOTAL_STEPS=10

# --- Resolve function OCIDs from terraform output or OCI CLI ---
resolve_function_ids() {
  info "Resolving function OCIDs..."

  # Try terraform output first
  local tf_dir="$SCRIPT_DIR/../terraform/scanning-tenancy"
  if [[ -d "$tf_dir/.terraform" ]]; then
    FUNC_IDS_JSON=$(cd "$tf_dir" && terraform output -json function_ids 2>/dev/null || echo "{}")
    if [[ "$FUNC_IDS_JSON" != "{}" ]]; then
      info "Loaded function IDs from terraform output"
      return 0
    fi
  fi

  # Fall back to OCI CLI - list functions in the application
  local app_id
  app_id=$(oci fn application list \
    --compartment-id "$SCANNING_COMPARTMENT" \
    --display-name "snapshot-scanner-app" \
    --query 'data[0].id' --raw-output 2>/dev/null || echo "")

  if [[ -z "$app_id" || "$app_id" == "null" ]]; then
    fail "Cannot find function application 'snapshot-scanner-app'"
    exit 1
  fi

  FUNC_IDS_JSON=$(oci fn function list \
    --application-id "$app_id" \
    --query 'data[].{key:"display-name", value:id}' \
    --output json 2>/dev/null \
    | jq 'from_entries' 2>/dev/null || echo "{}")

  if [[ "$FUNC_IDS_JSON" == "{}" ]]; then
    fail "No functions found in application $app_id"
    exit 1
  fi

  info "Loaded $(echo "$FUNC_IDS_JSON" | jq length) function IDs from OCI CLI"
}

get_fn_id() {
  local name="$1"
  # Try exact match, then with underscores, then with hyphens
  local id
  id=$(echo "$FUNC_IDS_JSON" | jq -r ".[\"$name\"] // .[\"$(echo "$name" | tr '-' '_')\"] // .[\"$(echo "$name" | tr '_' '-')\"] // empty" 2>/dev/null || echo "")
  if [[ -z "$id" ]]; then
    warn "Function '$name' not found in function IDs map"
    return 1
  fi
  echo "$id"
}

# --- Invoke a function and capture output ---
invoke_fn() {
  local fn_name="$1"
  local payload="$2"
  local fn_id

  fn_id=$(get_fn_id "$fn_name") || { fail "Cannot resolve OCID for $fn_name"; return 1; }

  if $DRY_RUN; then
    info "[DRY RUN] Would invoke $fn_name with:"
    echo "$payload" | jq . 2>/dev/null || echo "$payload"
    echo '{"dry_run": true}'
    return 0
  fi

  info "Invoking $fn_name ($fn_id)..."
  local result
  result=$(echo "$payload" | oci fn function invoke \
    --function-id "$fn_id" \
    --body file:///dev/stdin \
    --raw-output 2>/dev/null) || {
      fail "Function invocation failed: $fn_name"
      return 1
    }

  echo "$result"
}

# --- Query NoSQL table ---
query_nosql() {
  local statement="$1"
  oci nosql query execute \
    --compartment-id "$SCANNING_COMPARTMENT" \
    --statement "$statement" \
    --query 'data.items' \
    --output json 2>/dev/null || echo "[]"
}

# --- Wait for a condition with polling ---
poll_until() {
  local description="$1"
  local check_cmd="$2"
  local max_attempts="${3:-30}"
  local interval="${4:-10}"

  info "Waiting for: $description (max ${max_attempts}x${interval}s)"
  for ((i=1; i<=max_attempts; i++)); do
    if eval "$check_cmd" 2>/dev/null; then
      log "$description"
      return 0
    fi
    sleep "$interval"
    printf "."
  done
  echo ""
  fail "Timed out waiting for: $description"
  return 1
}

###############################################################################
# Print header
###############################################################################
echo ""
echo "============================================"
echo "  OCI Snapshot Scanner - Integration Test"
echo "============================================"
echo "  Scanning Compartment: $SCANNING_COMPARTMENT"
echo "  Target Tenancy:       $TARGET_TENANCY"
echo "  Target Compartment:   $TARGET_COMPARTMENT"
echo "  Region:               $REGION"
echo "  Dry Run:              $DRY_RUN"
echo "  Start Step:           ${START_STEP:-0}"
echo "============================================"
echo ""

resolve_function_ids

###############################################################################
# Step 1: Store scan configuration via app-config-store
###############################################################################
if [[ $START_STEP -le 1 ]]; then
step 1 "Store scan configuration"

SCAN_CONFIG=$(cat <<'CONF'
{
  "regions": "REGION_PLACEHOLDER",
  "scannerPlatforms": ["LINUX"],
  "swcaEnabled": "Disabled",
  "secretEnabled": "Disabled",
  "scanIntervalHours": 24,
  "maxConcurrentBackups": 10
}
CONF
)
# Replace placeholder with actual region
SCAN_CONFIG=$(echo "$SCAN_CONFIG" | sed "s/REGION_PLACEHOLDER/$REGION/")

CONFIG_RESULT=$(invoke_fn "app-config-store" "$(cat <<EOF
{
  "operation": "put",
  "configId": "scan-config",
  "configType": "SCAN_CONFIG",
  "configValue": $(echo "$SCAN_CONFIG" | jq -Rs .)
}
EOF
)")

if echo "$CONFIG_RESULT" | jq -e '.success == true' >/dev/null 2>&1; then
  log "Scan config stored"
  PASS=$((PASS + 1))
else
  fail "Failed to store scan config: $CONFIG_RESULT"
fi

# Verify we can read it back
VERIFY_RESULT=$(invoke_fn "app-config-store" '{"operation":"get","configId":"scan-config"}')
if echo "$VERIFY_RESULT" | jq -e '.configValue' >/dev/null 2>&1; then
  log "Scan config verified (read-back)"
  PASS=$((PASS + 1))
else
  fail "Failed to read back scan config"
fi
fi

###############################################################################
# Step 2: Event ingestion via API Gateway or direct function invoke
###############################################################################
if [[ $START_STEP -le 2 ]]; then
step 2 "Event ingestion (simulate instance launch in target)"

TEST_INSTANCE_ID="ocid1.instance.oc1.${REGION}.test$(date +%s)"
EVENT_PAYLOAD=$(cat <<EOF
{
  "source": "integration-test",
  "tenancyId": "$TARGET_TENANCY",
  "event": {
    "eventType": "com.oraclecloud.computeapi.launchinstance.end",
    "cloudEventsVersion": "0.1",
    "eventTypeVersion": "2.0",
    "source": "$REGION",
    "eventId": "test-$(date +%s)",
    "eventTime": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
    "contentType": "application/json",
    "data": {
      "compartmentId": "$TARGET_COMPARTMENT",
      "compartmentName": "test-compartment",
      "resourceName": "integration-test-instance",
      "resourceId": "$TEST_INSTANCE_ID",
      "availabilityDomain": "$(oci iam availability-domain list --compartment-id "$SCANNING_COMPARTMENT" --query 'data[0].name' --raw-output 2>/dev/null || echo 'AD-1')",
      "freeformTags": {},
      "definedTags": {}
    }
  },
  "forwardedAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
}
EOF
)

# Try API Gateway first, fall back to direct invoke
if [[ -n "$API_GATEWAY_ENDPOINT" ]]; then
  info "Sending event via API Gateway: $API_GATEWAY_ENDPOINT/events"
  HTTP_CODE=$(curl -s -o /tmp/inttest-event-resp.json -w "%{http_code}" \
    -X POST "$API_GATEWAY_ENDPOINT/events" \
    -H "Content-Type: application/json" \
    -d "$EVENT_PAYLOAD" 2>/dev/null || echo "000")

  if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "202" ]]; then
    log "Event accepted via API Gateway (HTTP $HTTP_CODE)"
    PASS=$((PASS + 1))
  else
    warn "API Gateway returned HTTP $HTTP_CODE - falling back to direct invoke"
    RESULT=$(invoke_fn "event-task-scheduler" "$EVENT_PAYLOAD")
    echo "$RESULT" | jq . 2>/dev/null || echo "$RESULT"
  fi
else
  RESULT=$(invoke_fn "event-task-scheduler" "$EVENT_PAYLOAD")
  if echo "$RESULT" | jq -e '.taskId' >/dev/null 2>&1; then
    EVENT_TASK_ID=$(echo "$RESULT" | jq -r '.taskId')
    log "Event processed, discovery task created: $EVENT_TASK_ID"
    PASS=$((PASS + 1))
  else
    fail "Event processing failed: $RESULT"
  fi
fi

# Verify event log was created
sleep 3
EVENT_LOG=$(query_nosql "SELECT * FROM snapshot_event_logs WHERE instanceId = '$TEST_INSTANCE_ID'")
if echo "$EVENT_LOG" | jq -e '.[0].instanceId' >/dev/null 2>&1; then
  log "Event log record created in NoSQL"
  PASS=$((PASS + 1))
else
  warn "Event log not found (may need more time or function didn't write it)"
fi

# Verify discovery task was created
DISC_TASKS=$(query_nosql "SELECT * FROM snapshot_discovery_task WHERE tenancyId = '$TARGET_TENANCY' AND taskStatus IN ('PENDING','IN_PROGRESS') LIMIT 1")
if echo "$DISC_TASKS" | jq -e '.[0].TaskId' >/dev/null 2>&1; then
  EVENT_TASK_ID=$(echo "$DISC_TASKS" | jq -r '.[0].TaskId')
  log "Discovery task confirmed in NoSQL: $EVENT_TASK_ID"
  PASS=$((PASS + 1))
else
  warn "Discovery task not found in NoSQL"
fi
fi

###############################################################################
# Step 3: Scheduled discovery (simulates qflow periodic trigger)
###############################################################################
if [[ $START_STEP -le 3 ]]; then
step 3 "Scheduled discovery"

SCHED_RESULT=$(invoke_fn "discovery-scheduler" "$(cat <<EOF
{
  "targetTenancies": [
    {
      "tenancyId": "$TARGET_TENANCY",
      "compartmentId": "$TARGET_COMPARTMENT"
    }
  ],
  "regions": ["$REGION"],
  "forceRediscovery": true
}
EOF
)")

if echo "$SCHED_RESULT" | jq -e '.tasksCreated >= 1' >/dev/null 2>&1; then
  SCHEDULED_TASK_IDS=$(echo "$SCHED_RESULT" | jq -r '.taskIds[]' 2>/dev/null)
  SCHEDULED_TASK_ID=$(echo "$SCHEDULED_TASK_IDS" | head -1)
  log "Discovery scheduler created tasks: $SCHEDULED_TASK_IDS"
  PASS=$((PASS + 1))
else
  fail "Discovery scheduler failed: $SCHED_RESULT"
  SCHEDULED_TASK_ID=""
fi
fi

###############################################################################
# Step 4: Discovery worker (cross-tenancy instance enumeration)
###############################################################################
if [[ $START_STEP -le 4 ]]; then
step 4 "Discovery worker (cross-tenancy)"

# Use the scheduled task ID, or fall back to creating one
TASK_ID="${SCHEDULED_TASK_ID:-$(uuidgen | tr '[:upper:]' '[:lower:]')}"

DISC_RESULT=$(invoke_fn "discovery-worker" "$(cat <<EOF
{
  "taskId": "$TASK_ID",
  "tenancyId": "$TARGET_TENANCY",
  "region": "$REGION",
  "compartmentId": "$TARGET_COMPARTMENT"
}
EOF
)")

if echo "$DISC_RESULT" | jq -e '.status == "COMPLETED"' >/dev/null 2>&1; then
  RESOURCE_COUNT=$(echo "$DISC_RESULT" | jq -r '.resourceCount')
  log "Discovery completed: found $RESOURCE_COUNT resources"
  PASS=$((PASS + 1))
else
  fail "Discovery worker failed: $DISC_RESULT"
  RESOURCE_COUNT=0
fi

# Verify resource_inventory populated
INVENTORY=$(query_nosql "SELECT * FROM snapshot_resource_inventory WHERE region = '$REGION' AND state = 'RUNNING' LIMIT 5")
INVENTORY_COUNT=$(echo "$INVENTORY" | jq 'length')
info "Resource inventory has $INVENTORY_COUNT records for $REGION"

if [[ "$INVENTORY_COUNT" -gt 0 ]]; then
  # Pick the first real resource for the rest of the pipeline
  REAL_RESOURCE_ID=$(echo "$INVENTORY" | jq -r '.[0].resourceId // empty')
  REAL_PLATFORM=$(echo "$INVENTORY" | jq -r '.[0].platform // "LINUX"')
  REAL_AD=$(echo "$INVENTORY" | jq -r '.[0].availabilityDomain // empty')
  REAL_VOLUMES=$(echo "$INVENTORY" | jq -c '.[0].volumes // []')
  log "Using resource for pipeline: $REAL_RESOURCE_ID ($REAL_PLATFORM)"
  PASS=$((PASS + 1))
else
  warn "No resources in inventory - subsequent steps will use synthetic data"
  REAL_RESOURCE_ID=""
  REAL_PLATFORM="LINUX"
fi
fi

###############################################################################
# Step 5: Generate scan chunks + create scan status
###############################################################################
if [[ $START_STEP -le 5 ]]; then
step 5 "Generate scan chunks and create scan status"

CHUNK_RESULT=$(invoke_fn "generate-scan-chunks" "$(cat <<EOF
{
  "scanConfig": {
    "swcaEnabled": "Disabled",
    "secretEnabled": "Disabled",
    "scannerPlatforms": ["LINUX"]
  },
  "resourceCount": ${RESOURCE_COUNT:-1},
  "chunkSize": 10
}
EOF
)")

if echo "$CHUNK_RESULT" | jq -e '.totalChunks >= 1' >/dev/null 2>&1; then
  TOTAL_CHUNKS=$(echo "$CHUNK_RESULT" | jq -r '.totalChunks')
  log "Generated $TOTAL_CHUNKS scan chunks"
  PASS=$((PASS + 1))
else
  fail "Generate scan chunks failed: $CHUNK_RESULT"
fi

# Create scan status records (use real resource if available)
if [[ -n "${REAL_RESOURCE_ID:-}" ]]; then
  STATUS_RESULT=$(invoke_fn "create-scan-status" "$(cat <<EOF
{
  "resources": [
    {
      "resourceId": "$REAL_RESOURCE_ID",
      "region": "$REGION",
      "platform": "$REAL_PLATFORM"
    }
  ],
  "scanTypes": ["VULN"]
}
EOF
)")

  if echo "$STATUS_RESULT" | jq -e '.created >= 1' >/dev/null 2>&1; then
    log "Scan status records created: $(echo "$STATUS_RESULT" | jq -r '.created')"
    PASS=$((PASS + 1))
  else
    fail "Create scan status failed: $STATUS_RESULT"
  fi

  # Verify in NoSQL
  SCAN_STATUS=$(query_nosql "SELECT * FROM snapshot_scan_status WHERE ResourceId = '$REAL_RESOURCE_ID'")
  if echo "$SCAN_STATUS" | jq -e '.[0].ResourceId' >/dev/null 2>&1; then
    log "Scan status record verified in NoSQL"
    PASS=$((PASS + 1))
  else
    warn "Scan status not found in NoSQL"
  fi
else
  warn "Skipping scan status creation (no real resources discovered)"
fi
fi

###############################################################################
# Step 6: Fetch inventory chunks
###############################################################################
if [[ $START_STEP -le 6 ]]; then
step 6 "Fetch inventory chunks"

FETCH_RESULT=$(invoke_fn "fetch-inventory-chunks" "$(cat <<EOF
{
  "region": "$REGION",
  "platform": "${REAL_PLATFORM:-LINUX}",
  "chunkIndex": 0,
  "chunkSize": 10
}
EOF
)")

if echo "$FETCH_RESULT" | jq -e '.count >= 0' >/dev/null 2>&1; then
  CHUNK_COUNT=$(echo "$FETCH_RESULT" | jq -r '.count')
  log "Fetched inventory chunk: $CHUNK_COUNT resources"
  PASS=$((PASS + 1))
else
  fail "Fetch inventory chunks failed: $FETCH_RESULT"
fi
fi

###############################################################################
# Step 7: Backup creation via oci-sdk-wrapper (cross-tenancy)
###############################################################################
if [[ $START_STEP -le 7 ]]; then
step 7 "Backup creation (cross-tenancy via oci-sdk-wrapper)"

if [[ -n "${REAL_RESOURCE_ID:-}" ]]; then
  # Get the first boot volume ID from the discovered resource
  BOOT_VOLUME_ID=$(echo "${REAL_VOLUMES:-[]}" | jq -r '.[0].volumeId // empty' 2>/dev/null)

  if [[ -n "$BOOT_VOLUME_ID" && "$BOOT_VOLUME_ID" != "null" ]]; then
    info "Creating backup for boot volume: $BOOT_VOLUME_ID"

    BACKUP_RESULT=$(invoke_fn "oci-sdk-wrapper" "$(cat <<EOF
{
  "service": "blockstorage",
  "operation": "createBootVolumeBackup",
  "region": "$REGION",
  "params": {
    "createBootVolumeBackupDetails": {
      "bootVolumeId": "$BOOT_VOLUME_ID",
      "displayName": "inttest-backup-$(date +%s)",
      "type": "INCREMENTAL",
      "freeformTags": {
        "App": "snapshot-scanner",
        "IntegrationTest": "true"
      }
    }
  }
}
EOF
)")

    if echo "$BACKUP_RESULT" | jq -e '.statusCode == 200' >/dev/null 2>&1; then
      BACKUP_ID=$(echo "$BACKUP_RESULT" | jq -r '.data.bootVolumeBackup.id // .data.id // empty')
      log "Backup created: $BACKUP_ID"
      PASS=$((PASS + 1))

      # Poll until backup is AVAILABLE
      if [[ -n "$BACKUP_ID" && "$BACKUP_ID" != "null" ]]; then
        poll_until "Backup to become AVAILABLE" \
          "oci bv boot-volume-backup get --boot-volume-backup-id '$BACKUP_ID' --query 'data.\"lifecycle-state\"' --raw-output 2>/dev/null | grep -q 'AVAILABLE'" \
          60 15
      fi
    else
      warn "Backup creation returned non-200: $(echo "$BACKUP_RESULT" | jq -r '.statusCode // "unknown"')"
      warn "This may be expected if cross-tenancy policies haven't propagated"
      BACKUP_ID=""
    fi
  else
    warn "No boot volume ID found - skipping backup test"
    BACKUP_ID=""
  fi
else
  warn "No real resources available - testing oci-sdk-wrapper with ListInstances instead"

  LIST_RESULT=$(invoke_fn "oci-sdk-wrapper" "$(cat <<EOF
{
  "service": "compute",
  "operation": "listInstances",
  "region": "$REGION",
  "params": {
    "compartmentId": "$SCANNING_COMPARTMENT",
    "limit": 1
  }
}
EOF
)")

  if echo "$LIST_RESULT" | jq -e '.statusCode == 200' >/dev/null 2>&1; then
    log "oci-sdk-wrapper working (ListInstances returned 200)"
    PASS=$((PASS + 1))
  else
    fail "oci-sdk-wrapper failed: $LIST_RESULT"
  fi
  BACKUP_ID=""
fi
fi

###############################################################################
# Step 8: Generate scan params (verifies parameter building logic)
###############################################################################
if [[ $START_STEP -le 8 ]]; then
step 8 "Generate scanner launch parameters"

# Get the AD and subnet
AVAIL_DOMAIN=$(oci iam availability-domain list \
  --compartment-id "$SCANNING_COMPARTMENT" \
  --query 'data[0].name' --raw-output 2>/dev/null || echo "AD-1")

RESOURCE_FOR_PARAMS="${REAL_RESOURCE_ID:-ocid1.instance.oc1.${REGION}.synthetic}"

PARAMS_RESULT=$(invoke_fn "generate-scan-params" "$(cat <<EOF
{
  "resource": {
    "resourceId": "$RESOURCE_FOR_PARAMS",
    "tenancyId": "$TARGET_TENANCY",
    "region": "$REGION",
    "platform": "${REAL_PLATFORM:-LINUX}",
    "state": "RUNNING",
    "volumes": []
  },
  "scanType": "VULN",
  "volumeIds": ["ocid1.volume.oc1.${REGION}.synthetic"],
  "scannerImageId": "${SCANNER_IMAGE_ID:-ocid1.image.oc1.${REGION}.placeholder}",
  "subnetId": "ocid1.subnet.oc1.${REGION}.placeholder",
  "nsgIds": [],
  "compartmentId": "$SCANNING_COMPARTMENT",
  "availabilityDomain": "$AVAIL_DOMAIN"
}
EOF
)")

if echo "$PARAMS_RESULT" | jq -e '.displayName' >/dev/null 2>&1; then
  SCANNER_NAME=$(echo "$PARAMS_RESULT" | jq -r '.displayName')
  log "Scanner params generated: $SCANNER_NAME"
  PASS=$((PASS + 1))
else
  fail "Generate scan params failed: $PARAMS_RESULT"
fi
fi

###############################################################################
# Step 9: NoSQL wrapper - direct CRUD verification
###############################################################################
if [[ $START_STEP -le 9 ]]; then
step 9 "NoSQL wrapper CRUD operations"

# Put a test record
NOSQL_PUT=$(invoke_fn "nosql-wrapper" "$(cat <<EOF
{
  "operation": "put",
  "tableName": "snapshot_app_config",
  "item": {
    "configId": "integration-test",
    "idx": 0,
    "configValue": "test-value-$(date +%s)",
    "configType": "TEST",
    "updatedAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
  }
}
EOF
)")

if echo "$NOSQL_PUT" | jq -e '.success == true' >/dev/null 2>&1; then
  log "NoSQL put succeeded"
  PASS=$((PASS + 1))
else
  fail "NoSQL put failed: $NOSQL_PUT"
fi

# Get it back
NOSQL_GET=$(invoke_fn "nosql-wrapper" "$(cat <<EOF
{
  "operation": "get",
  "tableName": "snapshot_app_config",
  "key": {"configId": "integration-test", "idx": 0}
}
EOF
)")

if echo "$NOSQL_GET" | jq -e '.item.configId == "integration-test"' >/dev/null 2>&1; then
  log "NoSQL get succeeded"
  PASS=$((PASS + 1))
else
  fail "NoSQL get failed: $NOSQL_GET"
fi

# Query
NOSQL_QUERY=$(invoke_fn "nosql-wrapper" "$(cat <<EOF
{
  "operation": "query",
  "tableName": "snapshot_app_config",
  "statement": "SELECT * FROM snapshot_app_config WHERE configId = \$configId",
  "variables": {"configId": "integration-test"}
}
EOF
)")

if echo "$NOSQL_QUERY" | jq -e '.items | length >= 1' >/dev/null 2>&1; then
  log "NoSQL query succeeded"
  PASS=$((PASS + 1))
else
  fail "NoSQL query failed: $NOSQL_QUERY"
fi

# Delete
NOSQL_DEL=$(invoke_fn "nosql-wrapper" "$(cat <<EOF
{
  "operation": "delete",
  "tableName": "snapshot_app_config",
  "key": {"configId": "integration-test", "idx": 0}
}
EOF
)")

if echo "$NOSQL_DEL" | jq -e '.success == true' >/dev/null 2>&1; then
  log "NoSQL delete succeeded"
  PASS=$((PASS + 1))
else
  fail "NoSQL delete failed: $NOSQL_DEL"
fi
fi

###############################################################################
# Step 10: Cleanup test resources
###############################################################################
if [[ $START_STEP -le 10 ]]; then
step 10 "Cleanup test resources"

if $SKIP_CLEANUP; then
  warn "Cleanup skipped (--skip-cleanup)"
else
  # Clean up any backup we created
  if [[ -n "${BACKUP_ID:-}" && "${BACKUP_ID}" != "null" ]]; then
    info "Deleting test backup: $BACKUP_ID"
    CLEANUP_RESULT=$(invoke_fn "oci-sdk-wrapper" "$(cat <<EOF
{
  "service": "blockstorage",
  "operation": "deleteBootVolumeBackup",
  "region": "$REGION",
  "params": {
    "bootVolumeBackupId": "$BACKUP_ID"
  }
}
EOF
)")
    if echo "$CLEANUP_RESULT" | jq -e '.statusCode == 200 or .statusCode == 204' >/dev/null 2>&1; then
      log "Test backup deleted"
    else
      warn "Backup cleanup may have failed: $CLEANUP_RESULT"
    fi
  fi

  # Clean up discovery tasks and event logs created by this test
  info "Cleaning up test NoSQL records..."

  invoke_fn "nosql-wrapper" "$(cat <<EOF
{
  "operation": "query",
  "tableName": "snapshot_event_logs",
  "statement": "SELECT UID FROM snapshot_event_logs WHERE instanceId = '$TEST_INSTANCE_ID'"
}
EOF
)" | jq -r '.items[]?.UID // empty' 2>/dev/null | while read -r uid; do
    invoke_fn "nosql-wrapper" "{\"operation\":\"delete\",\"tableName\":\"snapshot_event_logs\",\"key\":{\"UID\":\"$uid\"}}" >/dev/null 2>&1
  done

  # Clean up scan status records
  if [[ -n "${REAL_RESOURCE_ID:-}" ]]; then
    invoke_fn "nosql-wrapper" "$(cat <<EOF
{
  "operation": "delete",
  "tableName": "snapshot_scan_status",
  "key": {"ResourceId": "$REAL_RESOURCE_ID", "ScanType": "VULN"}
}
EOF
)" >/dev/null 2>&1 || true
  fi

  log "Test resource cleanup done"
  PASS=$((PASS + 1))
fi
fi

###############################################################################
# Summary
###############################################################################
echo ""
echo "============================================"
echo "  Integration Test Results"
echo "============================================"
echo -e "  Passed: ${GREEN}$PASS${NC}"
echo -e "  Failed: ${RED}$FAILURES${NC}"
echo "============================================"

if [[ $FAILURES -gt 0 ]]; then
  echo ""
  echo -e "${YELLOW}Some tests failed. Common reasons:${NC}"
  echo "  - Cross-tenancy policies haven't propagated (can take 10+ minutes)"
  echo "  - Functions haven't been deployed/built yet"
  echo "  - NoSQL tables or queues don't exist (run terraform apply first)"
  echo "  - No running compute instances in target tenancy"
  echo ""
  echo "  Re-run from a specific step: $0 --step N"
  echo "  Dry run (show payloads only):  $0 --dry-run"
fi

[[ $FAILURES -eq 0 ]] && exit 0 || exit 1
