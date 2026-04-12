#!/usr/bin/env bash
#
# USH-22 · Integration Test: SAST Full Pipeline
#
# Automated end-to-end test of the SAST scanning pipeline:
#   1. Create scan job via POST /scan-jobs
#   2. Upload known-vulnerable JS file via presigned S3 URL
#   3. Start scan via POST /scan-jobs/{findingId}/start
#   4. Poll for status transitions: PENDING → RUNNING → COMPLETED
#   5. Download report from S3
#   6. Validate report contains expected vulnerability categories
#
# Prerequisites:
#   - AWS CLI configured with valid Learner Lab credentials
#   - jq installed (brew install jq / apt install jq)
#   - Infrastructure deployed (terraform apply)
#   - Docker images pushed (bash docs/script.sh)
#
# Usage:
#   # From project root:
#   cd terrafrom && source <(terraform output -json | jq -r 'to_entries[] | "export TF_\(.key | ascii_upcase)=\(.value.value)"') && cd ..
#   bash tests/test_sast_pipeline.sh
#
#   # Or set variables manually:
#   export API_URL=https://xxx.execute-api.us-east-1.amazonaws.com/dev/scan-jobs
#   export API_KEY=your-api-key-value
#   export ARTIFACTS_BUCKET=ush-artifacts-123456789012
#   bash tests/test_sast_pipeline.sh
#
set -euo pipefail

##############################################################################
# Colors & helpers
##############################################################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

pass()  { echo -e "  ${GREEN}✓${NC} $1"; }
fail()  { echo -e "  ${RED}✗${NC} $1"; FAILURES=$((FAILURES + 1)); }
info()  { echo -e "  ${CYAN}ℹ${NC} $1"; }
header(){ echo -e "\n${BOLD}${YELLOW}━━━ $1 ━━━${NC}"; }

FAILURES=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

##############################################################################
# Configuration — read from env or derive from Terraform
##############################################################################
header "Configuration"

# If API_URL is not set, try to get it from Terraform
if [[ -z "${API_URL:-}" ]]; then
  if [[ -d "terrafrom" ]]; then
    info "Reading Terraform outputs from terrafrom/ ..."
    API_URL=$(cd terrafrom && terraform output -raw api_url 2>/dev/null) || true
    ARTIFACTS_BUCKET=$(cd terrafrom && terraform output -raw artifacts_bucket 2>/dev/null) || true
    API_KEY_ID=$(cd terrafrom && terraform output -raw api_key_id 2>/dev/null) || true
    if [[ -n "${API_KEY_ID:-}" && -z "${API_KEY:-}" ]]; then
      API_KEY=$(aws apigateway get-api-key --api-key "$API_KEY_ID" --include-value --query "value" --output text 2>/dev/null) || true
    fi
  fi
fi

# Also accept TF_ prefixed vars (from the jq sourcing pattern)
API_URL="${API_URL:-${TF_API_URL:-}}"
API_KEY="${API_KEY:-${TF_API_KEY:-}}"
ARTIFACTS_BUCKET="${ARTIFACTS_BUCKET:-${TF_ARTIFACTS_BUCKET:-}}"

# Validate required vars
for var in API_URL API_KEY ARTIFACTS_BUCKET; do
  if [[ -z "${!var:-}" ]]; then
    echo -e "${RED}ERROR:${NC} $var is not set. See usage instructions at the top of this script."
    exit 1
  fi
done

POLL_INTERVAL="${POLL_INTERVAL:-10}"
MAX_POLL_ATTEMPTS="${MAX_POLL_ATTEMPTS:-30}"  # 30 × 10s = 5 min max

info "API_URL:          $API_URL"
info "API_KEY:          ${API_KEY:0:8}..."
info "ARTIFACTS_BUCKET: $ARTIFACTS_BUCKET"
info "POLL_INTERVAL:    ${POLL_INTERVAL}s (max ${MAX_POLL_ATTEMPTS} attempts)"

# Check jq
if ! command -v jq &>/dev/null; then
  echo -e "${RED}ERROR:${NC} jq is required but not installed."
  exit 1
fi

##############################################################################
# Step 1: Prepare test file
##############################################################################
header "Step 1 — Prepare vulnerable test file"

TEST_FILE="${SCRIPT_DIR}/test-sast.js"
ZIP_FILE="/tmp/test-sast-$$.zip"
rm -f "$ZIP_FILE"

if [[ ! -f "$TEST_FILE" ]]; then
  echo -e "${RED}ERROR:${NC} Test file not found: $TEST_FILE"
  echo "Make sure test-sast.js is in the same directory as this script."
  exit 1
fi

(cd "$(dirname "$TEST_FILE")" && zip -j "$ZIP_FILE" "$(basename "$TEST_FILE")" >/dev/null 2>&1)
pass "Created test zip: $ZIP_FILE ($(wc -c < "$ZIP_FILE") bytes)"

##############################################################################
# Step 2: Create scan job
##############################################################################
header "Step 2 — Create SAST scan job"

CREATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"scanType": "SAST", "userId": "integration-test"}')

HTTP_CODE=$(echo "$CREATE_RESPONSE" | tail -1)
BODY=$(echo "$CREATE_RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" == "201" ]]; then
  pass "Job created (HTTP $HTTP_CODE)"
else
  fail "Job creation failed (HTTP $HTTP_CODE): $BODY"
  exit 1
fi

FINDING_ID=$(echo "$BODY" | jq -r '.findingId')
UPLOAD_URL=$(echo "$BODY" | jq -r '.uploadUrl')
STATUS=$(echo "$BODY" | jq -r '.status')

if [[ "$STATUS" == "PENDING" ]]; then
  pass "Initial status: PENDING"
else
  fail "Expected status PENDING, got: $STATUS"
fi

info "Finding ID: $FINDING_ID"

##############################################################################
# Step 3: Upload test file to S3
##############################################################################
header "Step 3 — Upload test zip via presigned URL"

UPLOAD_HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$UPLOAD_URL" \
  -H "Content-Type: application/zip" \
  --data-binary @"$ZIP_FILE")

if [[ "$UPLOAD_HTTP" == "200" ]]; then
  pass "File uploaded to S3 (HTTP $UPLOAD_HTTP)"
else
  fail "Upload failed (HTTP $UPLOAD_HTTP)"
  exit 1
fi

##############################################################################
# Step 4: Start the scan
##############################################################################
header "Step 4 — Start scan"

START_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/$FINDING_ID/start" \
  -H "x-api-key: $API_KEY")

HTTP_CODE=$(echo "$START_RESPONSE" | tail -1)
BODY=$(echo "$START_RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" == "200" ]]; then
  START_STATUS=$(echo "$BODY" | jq -r '.status')
  if [[ "$START_STATUS" == "RUNNING" ]]; then
    pass "Scan started — status: RUNNING"
  else
    fail "Expected status RUNNING after start, got: $START_STATUS"
  fi
else
  fail "Start scan failed (HTTP $HTTP_CODE): $BODY"
  exit 1
fi

##############################################################################
# Step 5: Poll for completion
##############################################################################
header "Step 5 — Poll for status transitions"

SAW_RUNNING=false
FINAL_STATUS=""
ATTEMPT=0

while [[ $ATTEMPT -lt $MAX_POLL_ATTEMPTS ]]; do
  ATTEMPT=$((ATTEMPT + 1))

  POLL_RESPONSE=$(curl -s "$API_URL/$FINDING_ID" -H "x-api-key: $API_KEY")
  CURRENT_STATUS=$(echo "$POLL_RESPONSE" | jq -r '.status')

  if [[ "$CURRENT_STATUS" == "RUNNING" ]]; then
    SAW_RUNNING=true
    printf "  ⏳ [%02d/%d] Status: RUNNING ...\r" "$ATTEMPT" "$MAX_POLL_ATTEMPTS"
  elif [[ "$CURRENT_STATUS" == "COMPLETED" ]]; then
    echo ""
    FINAL_STATUS="COMPLETED"
    break
  elif [[ "$CURRENT_STATUS" == "FAILED" ]]; then
    echo ""
    FINAL_STATUS="FAILED"
    ERROR_MSG=$(echo "$POLL_RESPONSE" | jq -r '.errorMessage // "unknown"')
    break
  else
    printf "  ⏳ [%02d/%d] Status: %s ...\r" "$ATTEMPT" "$MAX_POLL_ATTEMPTS" "$CURRENT_STATUS"
  fi

  sleep "$POLL_INTERVAL"
done

# Validate status transitions
if [[ "$SAW_RUNNING" == "true" ]]; then
  pass "Status transition: PENDING → RUNNING observed"
else
  fail "Never observed RUNNING status"
fi

if [[ "$FINAL_STATUS" == "COMPLETED" ]]; then
  pass "Status transition: RUNNING → COMPLETED"
elif [[ "$FINAL_STATUS" == "FAILED" ]]; then
  fail "Scan ended with FAILED status: $ERROR_MSG"
  info "Check ECS logs: aws logs tail /ecs/security-hub-dev-sast --follow"
  exit 1
else
  fail "Timed out after $MAX_POLL_ATTEMPTS attempts (last status: $CURRENT_STATUS)"
  exit 1
fi

##############################################################################
# Step 6: Download and validate report
##############################################################################
header "Step 6 — Download report from S3"

REPORT_FILE=$(mktemp /tmp/sast-report-XXXXXX.json)
REPORT_KEY="reports/$FINDING_ID/report.json"

if aws s3 cp "s3://$ARTIFACTS_BUCKET/$REPORT_KEY" "$REPORT_FILE" >/dev/null 2>&1; then
  pass "Report downloaded: $REPORT_FILE"
else
  # Also try via API
  info "S3 direct download failed — trying API endpoint..."
  REPORT_RESPONSE=$(curl -s "$API_URL/$FINDING_ID/report" -H "x-api-key: $API_KEY")
  echo "$REPORT_RESPONSE" > "$REPORT_FILE"
  if echo "$REPORT_RESPONSE" | jq . >/dev/null 2>&1; then
    pass "Report downloaded via API"
  else
    fail "Could not download report from S3 or API"
    exit 1
  fi
fi

##############################################################################
# Step 7: Validate report contents
##############################################################################
header "Step 7 — Validate report findings"

# Check report structure
SCAN_TYPE=$(jq -r '.scanType' "$REPORT_FILE")
FINDING_COUNT=$(jq -r '.summary.total' "$REPORT_FILE")
SEVERITY=$(jq -r '.severity' "$REPORT_FILE")

if [[ "$SCAN_TYPE" == "SAST" ]]; then
  pass "Report scanType: SAST"
else
  fail "Expected scanType SAST, got: $SCAN_TYPE"
fi

if [[ "$SEVERITY" == "HIGH" ]]; then
  pass "Report severity: HIGH"
else
  fail "Expected severity HIGH, got: $SEVERITY"
fi

if [[ "$FINDING_COUNT" -gt 0 ]]; then
  pass "Report contains $FINDING_COUNT finding(s)"
else
  fail "Report contains 0 findings"
fi

# Extract all unique vulnerability IDs found
FOUND_RULE_IDS=$(jq -r '[.results[][] | .id] | unique | .[]' "$REPORT_FILE" 2>/dev/null || echo "")

# Expected rule IDs from scanner.js that our test file should trigger
EXPECTED_RULES=(
  "HARDCODED_SECRET"
  "SQL_INJECTION"
  "NOSQL_INJECTION"
  "XSS"
  "PATH_TRAVERSAL"
  "INSECURE_RANDOM"
  "SENSITIVE_DATA_LOG"
  "INSECURE_FUNCTION"
  "WEAK_CRYPTO"
  "SECURITY_TODO"
  "HARDCODED_IP"
)

RULES_FOUND=0
RULES_MISSING=0

for rule in "${EXPECTED_RULES[@]}"; do
  if echo "$FOUND_RULE_IDS" | grep -q "^${rule}$"; then
    pass "Found expected rule: $rule"
    RULES_FOUND=$((RULES_FOUND + 1))
  else
    fail "Missing expected rule: $rule"
    RULES_MISSING=$((RULES_MISSING + 1))
  fi
done

# Summary counts
SUMMARY_HIGH=$(jq -r '.summary.high' "$REPORT_FILE")
SUMMARY_MEDIUM=$(jq -r '.summary.medium' "$REPORT_FILE")
SUMMARY_LOW=$(jq -r '.summary.low' "$REPORT_FILE")

info "Severity breakdown: HIGH=$SUMMARY_HIGH  MEDIUM=$SUMMARY_MEDIUM  LOW=$SUMMARY_LOW"
info "Rules matched: $RULES_FOUND / ${#EXPECTED_RULES[@]}"

##############################################################################
# Step 8: Verify DynamoDB record
##############################################################################
header "Step 8 — Verify DynamoDB record"

TABLE_NAME="${DYNAMODB_TABLE:-unified-security-hub-findings-dev}"

DB_ITEM=$(aws dynamodb query \
  --table-name "$TABLE_NAME" \
  --key-condition-expression "finding_id = :id" \
  --expression-attribute-values "{\":id\": {\"S\": \"$FINDING_ID\"}}" \
  --query "Items[0]" \
  --output json 2>/dev/null || echo "{}")

if [[ "$DB_ITEM" != "{}" && "$DB_ITEM" != "null" ]]; then
  DB_STATUS=$(echo "$DB_ITEM" | jq -r '.status.S // "unknown"')
  DB_SEVERITY=$(echo "$DB_ITEM" | jq -r '.severity.S // "unknown"')
  DB_REPORT_KEY=$(echo "$DB_ITEM" | jq -r '.s3ReportKey.S // "not set"')

  if [[ "$DB_STATUS" == "COMPLETED" ]]; then
    pass "DynamoDB status: COMPLETED"
  else
    fail "DynamoDB status: $DB_STATUS (expected COMPLETED)"
  fi

  if [[ "$DB_SEVERITY" == "HIGH" ]]; then
    pass "DynamoDB severity: HIGH"
  else
    fail "DynamoDB severity: $DB_SEVERITY (expected HIGH)"
  fi

  if [[ "$DB_REPORT_KEY" != "not set" ]]; then
    pass "DynamoDB s3ReportKey: $DB_REPORT_KEY"
  else
    fail "DynamoDB s3ReportKey not set"
  fi
else
  fail "Could not read DynamoDB record (check table name or credentials)"
  info "Tried table: $TABLE_NAME"
fi

##############################################################################
# Cleanup
##############################################################################
rm -f "$ZIP_FILE"

##############################################################################
# Results
##############################################################################
header "Test Results"

TOTAL_CHECKS=$((RULES_FOUND + RULES_MISSING + 10))  # approximate

if [[ $FAILURES -eq 0 ]]; then
  echo -e "\n  ${GREEN}${BOLD}ALL TESTS PASSED${NC}"
  echo -e "  Pipeline: API → S3 → Step Functions → ECS Fargate → S3 Report → DynamoDB"
  echo -e "  Rules validated: $RULES_FOUND / ${#EXPECTED_RULES[@]}"
  echo -e "  Total findings: $FINDING_COUNT"
  echo ""
  exit 0
else
  echo -e "\n  ${RED}${BOLD}$FAILURES TEST(S) FAILED${NC}"
  echo -e "  Report saved: $REPORT_FILE"
  echo ""
  exit 1
fi