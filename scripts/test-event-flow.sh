#!/usr/bin/env bash
set -euo pipefail

# Test Event Flow - Simulates an instance launch event and traces it through the pipeline

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }

API_ENDPOINT="${API_GATEWAY_ENDPOINT:?Set API_GATEWAY_ENDPOINT (e.g. https://xxx.apigateway.us-ashburn-1.oci.customer-oci.com/v1)}"
API_KEY="${API_KEY:?Set API_KEY}"
SCANNING_COMPARTMENT="${SCANNING_COMPARTMENT_ID:?Set SCANNING_COMPARTMENT_ID}"

INSTANCE_ID="ocid1.instance.oc1.iad.test$(date +%s)"
EVENT_ID="test-event-$(date +%s)"

echo "============================================"
echo "  Event Flow Test"
echo "============================================"
echo "  API Endpoint: $API_ENDPOINT"
echo "  Test Instance: $INSTANCE_ID"
echo "============================================"
echo ""

# Step 1: Send test event to API Gateway
log "Step 1: Sending test event to API Gateway..."

EVENT_PAYLOAD=$(cat <<EOF
{
  "source": "event-forwarder",
  "tenancyId": "ocid1.tenancy.oc1..test",
  "event": {
    "eventType": "com.oraclecloud.computeapi.launchinstance.end",
    "cloudEventsVersion": "0.1",
    "eventTypeVersion": "2.0",
    "source": "us-ashburn-1",
    "eventId": "$EVENT_ID",
    "eventTime": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
    "contentType": "application/json",
    "data": {
      "compartmentId": "ocid1.compartment.oc1..test",
      "compartmentName": "test-compartment",
      "resourceName": "test-instance",
      "resourceId": "$INSTANCE_ID",
      "availabilityDomain": "Uocm:US-ASHBURN-AD-1",
      "freeformTags": {},
      "definedTags": {}
    }
  },
  "forwardedAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
}
EOF
)

HTTP_CODE=$(curl -s -o /tmp/event-response.json -w "%{http_code}" \
  -X POST "$API_ENDPOINT/events" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d "$EVENT_PAYLOAD")

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "202" ]]; then
  log "Event accepted (HTTP $HTTP_CODE)"
  cat /tmp/event-response.json | jq . 2>/dev/null || cat /tmp/event-response.json
else
  fail "Event rejected (HTTP $HTTP_CODE)"
  cat /tmp/event-response.json 2>/dev/null
  exit 1
fi

echo ""

# Step 2: Check event log in NoSQL
log "Step 2: Checking event log (waiting 10s for processing)..."
sleep 10

EVENT_LOG=$(oci nosql query execute \
  --compartment-id "$SCANNING_COMPARTMENT" \
  --statement "SELECT * FROM snapshot_event_logs WHERE instanceId = '$INSTANCE_ID'" \
  --query 'data.items[0]' \
  --raw-output 2>/dev/null || echo "{}")

if echo "$EVENT_LOG" | jq -e '.instanceId' >/dev/null 2>&1; then
  log "Event log record found!"
  echo "$EVENT_LOG" | jq .
else
  warn "Event log not yet found (may need more time)"
fi

echo ""

# Step 3: Check discovery task
log "Step 3: Checking discovery task..."

TASK=$(oci nosql query execute \
  --compartment-id "$SCANNING_COMPARTMENT" \
  --statement "SELECT * FROM snapshot_discovery_task WHERE taskType = 'EVENT_BASED' ORDER BY createdAt DESC LIMIT 1" \
  --query 'data.items[0]' \
  --raw-output 2>/dev/null || echo "{}")

if echo "$TASK" | jq -e '.TaskId' >/dev/null 2>&1; then
  log "Discovery task found!"
  echo "$TASK" | jq .
else
  warn "Discovery task not yet found"
fi

echo ""

# Step 4: Health check
log "Step 4: API Gateway health check..."
HEALTH=$(curl -s "$API_ENDPOINT/health")
echo "$HEALTH" | jq . 2>/dev/null || echo "$HEALTH"

echo ""
log "Event flow test complete."
