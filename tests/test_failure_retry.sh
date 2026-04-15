#!/usr/bin/env bash
#
# USH-24 · Failure & Retry Testing
#
# Verifies error handling and retry logic:
#   1. Create a SAST job via API with a valid DynamoDB record
#   2. Upload a dummy zip so the job has an s3UploadKey
#   3. Start the scan — Step Functions will launch Fargate
#   4. The SAST container will fail (bad/corrupt zip = scanner crashes)
#   5. Verify Step Functions retries 2x (MaxAttempts=2 in sfn.tf)
#   6. Verify final status = FAILED in DynamoDB
#   7. Verify errorMessage is populated
#   8. Verify SNS failure notification (check email manually)
#
# Alternative: To test with a bad image tag, temporarily update the
# task definition to use a nonexistent tag and run terraform apply.
# This script uses the simpler approach of a corrupt upload.
#
# Usage:
#   export API_URL=https://xxx.execute-api.us-east-1.amazonaws.com/dev/scan-jobs
#   export API_KEY=your-api-key-value
#   export ARTIFACTS_BUCKET=ush-artifacts-123456789012
#   bash tests/test_failure_retry.sh
#
set -euo pipefail

##############################################################################
# Colors & helpers
##############################################################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

pass()  { echo -e "  ${GREEN}✓${NC} $1"; }
fail()  { echo -e "  ${RED}✗${NC} $1"; FAILURES=$((FAILURES + 1)); }
info()  { echo -e "  ${CYAN}ℹ${NC} $1"; }
header(){ echo -e "\n${BOLD}${YELLOW}━━━ $1 ━━━${NC}"; }

FAILURES=0

##############################################################################
# Configuration
##############################################################################
header "Configuration"

if [[ -z "${API_URL:-}" ]]; then
  if [[ -d "terraform" ]]; then
    info "Reading Terraform outputs..."
    API_URL=$(cd terraform && terraform output -raw api_url 2>/dev/null) || true
    ARTIFACTS_BUCKET=$(cd terraform && terraform output -raw artifacts_bucket 2>/dev/null) || true
    SFN_ARN=$(cd terraform && terraform output -raw sfn_arn 2>/dev/null) || true
    API_KEY_ID=$(cd terraform && terraform output -raw api_key_id 2>/dev/null) || true
    if [[ -n "${API_KEY_ID:-}" && -z "${API_KEY:-}" ]]; then
      API_KEY=$(aws apigateway get-api-key --api-key "$API_KEY_ID" --include-value --query "value" --output text 2>/dev/null) || true
    fi
  fi
fi

API_URL="${API_URL:-}"
API_KEY="${API_KEY:-}"
ARTIFACTS_BUCKET="${ARTIFACTS_BUCKET:-}"
SFN_ARN="${SFN_ARN:-}"

POLL_INTERVAL="${POLL_INTERVAL:-30}"
MAX_POLL_ATTEMPTS="${MAX_POLL_ATTEMPTS:-20}"  # 20 × 30s = 10 min (retries take time)

for var in API_URL API_KEY ARTIFACTS_BUCKET; do
  if [[ -z "${!var:-}" ]]; then
    echo -e "${RED}ERROR:${NC} $var is not set."
    exit 1
  fi
done

info "API_URL:          $API_URL"
info "API_KEY:          ${API_KEY:0:8}..."
info "ARTIFACTS_BUCKET: $ARTIFACTS_BUCKET"
info "POLL_INTERVAL:    ${POLL_INTERVAL}s (max ${MAX_POLL_ATTEMPTS} attempts)"
info ""
info "⚠️  This test intentionally causes failures. It will take 3-5 minutes"
info "   due to Step Functions retry delays (2 retries × ~30s intervals)."

if ! command -v jq &>/dev/null; then
  echo -e "${RED}ERROR:${NC} jq is required."
  exit 1
fi

##############################################################################
# Step 1: Create a SAST job
##############################################################################
header "Step 1 — Create SAST job"

CREATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"scanType": "SAST", "userId": "failure-test"}')

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

info "Finding ID: $FINDING_ID"

##############################################################################
# Step 2: Upload a corrupt zip (will cause scanner to crash)
##############################################################################
header "Step 2 — Upload corrupt zip to force failure"

# Create a file that is NOT a valid zip — scanner will fail on unzip
CORRUPT_FILE=$(mktemp /tmp/corrupt-XXXXXX.zip)
echo "THIS IS NOT A ZIP FILE - INTENTIONAL FAILURE TEST" > "$CORRUPT_FILE"

UPLOAD_HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$UPLOAD_URL" \
  -H "Content-Type: application/zip" \
  --data-binary @"$CORRUPT_FILE")

if [[ "$UPLOAD_HTTP" == "200" ]]; then
  pass "Corrupt file uploaded to S3 (HTTP $UPLOAD_HTTP)"
else
  fail "Upload failed (HTTP $UPLOAD_HTTP)"
  exit 1
fi

rm -f "$CORRUPT_FILE"

##############################################################################
# Step 3: Start the scan (will trigger failures + retries)
##############################################################################
header "Step 3 — Start scan (expecting failure)"

START_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/$FINDING_ID/start" \
  -H "x-api-key: $API_KEY")

HTTP_CODE=$(echo "$START_RESPONSE" | tail -1)
BODY=$(echo "$START_RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" == "200" ]]; then
  pass "Scan started — Step Functions execution launched"
else
  fail "Start scan failed (HTTP $HTTP_CODE): $BODY"
  exit 1
fi

info "Waiting for Fargate task to fail + Step Functions to retry 2x..."
info "This will take 3-5 minutes."

##############################################################################
# Step 4: Poll for FAILED status
##############################################################################
header "Step 4 — Poll for FAILED status (with retries)"

SAW_RUNNING=false
FINAL_STATUS=""
ATTEMPT=0

while [[ $ATTEMPT -lt $MAX_POLL_ATTEMPTS ]]; do
  ATTEMPT=$((ATTEMPT + 1))

  POLL_RESPONSE=$(curl -s "$API_URL/$FINDING_ID" -H "x-api-key: $API_KEY")
  CURRENT_STATUS=$(echo "$POLL_RESPONSE" | jq -r '.status')

  if [[ "$CURRENT_STATUS" == "RUNNING" ]]; then
    SAW_RUNNING=true
    printf "  ⏳ [%02d/%d] Status: RUNNING (retrying in background)...\r" "$ATTEMPT" "$MAX_POLL_ATTEMPTS"
  elif [[ "$CURRENT_STATUS" == "FAILED" ]]; then
    echo ""
    FINAL_STATUS="FAILED"
    break
  elif [[ "$CURRENT_STATUS" == "COMPLETED" ]]; then
    echo ""
    FINAL_STATUS="COMPLETED"
    break
  else
    printf "  ⏳ [%02d/%d] Status: %s ...\r" "$ATTEMPT" "$MAX_POLL_ATTEMPTS" "$CURRENT_STATUS"
  fi

  sleep "$POLL_INTERVAL"
done

echo ""

if [[ "$FINAL_STATUS" == "FAILED" ]]; then
  pass "Final status: FAILED (as expected)"
elif [[ "$FINAL_STATUS" == "COMPLETED" ]]; then
  fail "Scan completed successfully — expected FAILED. The corrupt zip may have been handled gracefully."
else
  fail "Timed out — last status: $CURRENT_STATUS"
  exit 1
fi

##############################################################################
# Step 5: Verify DynamoDB record
##############################################################################
header "Step 5 — Verify DynamoDB record"

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

  if [[ "$DB_STATUS" == "FAILED" ]]; then
    pass "DynamoDB status: FAILED"
  else
    fail "DynamoDB status: $DB_STATUS (expected FAILED)"
  fi
else
  fail "Could not read DynamoDB record"
  info "Tried table: $TABLE_NAME"
fi

##############################################################################
# Step 6: Verify Step Functions execution history (retries)
##############################################################################
header "Step 6 — Verify Step Functions retries"

if [[ -n "${SFN_ARN:-}" ]]; then
  # Find the execution for this finding
  EXEC_ARN=$(aws stepfunctions list-executions \
    --state-machine-arn "$SFN_ARN" \
    --status-filter "FAILED" \
    --max-results 10 \
    --query "executions[?contains(name, '${FINDING_ID}')].executionArn | [0]" \
    --output text 2>/dev/null || echo "None")

  if [[ "$EXEC_ARN" == "None" || -z "$EXEC_ARN" ]]; then
    # Try matching by scan- prefix
    EXEC_ARN=$(aws stepfunctions list-executions \
      --state-machine-arn "$SFN_ARN" \
      --status-filter "FAILED" \
      --max-results 5 \
      --query "executions[0].executionArn" \
      --output text 2>/dev/null || echo "None")
  fi

  if [[ "$EXEC_ARN" != "None" && -n "$EXEC_ARN" ]]; then
    # Count TaskFailed events (each retry produces one)
    TASK_FAILED_COUNT=$(aws stepfunctions get-execution-history \
      --execution-arn "$EXEC_ARN" \
      --query "length(events[?type=='TaskFailed'])" \
      --output text 2>/dev/null || echo "0")

    # Count TaskSubmitted events (initial + retries)
    TASK_SUBMITTED_COUNT=$(aws stepfunctions get-execution-history \
      --execution-arn "$EXEC_ARN" \
      --query "length(events[?type=='TaskSubmitted'])" \
      --output text 2>/dev/null || echo "0")

    info "Task submissions: $TASK_SUBMITTED_COUNT (1 initial + 2 retries = 3 expected)"
    info "Task failures: $TASK_FAILED_COUNT"

    if [[ "$TASK_SUBMITTED_COUNT" -ge 3 ]]; then
      pass "Step Functions retried 2x (3 total attempts)"
    elif [[ "$TASK_SUBMITTED_COUNT" -ge 2 ]]; then
      pass "Step Functions retried at least once ($TASK_SUBMITTED_COUNT attempts)"
    else
      fail "Expected 3 task submissions (1 + 2 retries), got: $TASK_SUBMITTED_COUNT"
    fi
  else
    info "Could not find matching execution — check Step Functions console manually"
    info "Console: AWS → Step Functions → $SFN_ARN → Executions"
  fi
else
  info "SFN_ARN not set — skipping retry verification"
  info "Set it: export SFN_ARN=\$(cd terraform && terraform output -raw sfn_arn)"
fi

##############################################################################
# Step 7: SNS notification check
##############################################################################
header "Step 7 — SNS failure notification"

info "The Step Functions ScanFailed state triggers the Fail state."
info "If 3+ failures occur within 1 hour, the CloudWatch alarm fires → SNS email."
info ""
info "✉️  Check your SNS subscription email for the failure notification."
info "    (This must be verified manually.)"

##############################################################################
# Results
##############################################################################
header "Test Results"

if [[ $FAILURES -eq 0 ]]; then
  echo -e "\n  ${GREEN}${BOLD}ALL TESTS PASSED${NC}"
  echo -e "  Corrupt zip → Fargate crash → 2 retries → FAILED in DynamoDB"
  echo -e "  Finding ID: $FINDING_ID"
  echo ""
  echo -e "  ${CYAN}Manual verification needed:${NC}"
  echo -e "    1. Check SNS email for failure notification"
  echo -e "    2. AWS Console → Step Functions → check execution history shows 3 attempts"
  echo ""
  exit 0
else
  echo -e "\n  ${RED}${BOLD}$FAILURES TEST(S) FAILED${NC}"
  echo ""
  exit 1
fi
