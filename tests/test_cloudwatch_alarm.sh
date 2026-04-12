#!/usr/bin/env bash
#
# USH-26 · Test CloudWatch Alarm: Simulate 3 failed scans
#
# Triggers the "3+ failed scans in 1 hour" alarm by starting
# Step Functions executions with invalid data that will fail.
#
# After running, check:
#   1. CloudWatch Alarms console → alarm should go to ALARM state
#   2. SNS email → you should receive a failure notification
#
# Usage:
#   export SFN_ARN=arn:aws:states:us-east-1:123456789012:stateMachine:unified-security-hub-scanner-dev
#   bash tests/test_cloudwatch_alarm.sh
#
#   # Or auto-read from Terraform:
#   cd terraform && SFN_ARN=$(terraform output -raw sfn_arn) && cd ..
#   bash tests/test_cloudwatch_alarm.sh
#
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

info()  { echo -e "  ${CYAN}ℹ${NC} $1"; }
pass()  { echo -e "  ${GREEN}✓${NC} $1"; }
header(){ echo -e "\n${BOLD}${YELLOW}━━━ $1 ━━━${NC}"; }

# Get SFN ARN
if [[ -z "${SFN_ARN:-}" ]]; then
  if [[ -d "terraform" ]]; then
    SFN_ARN=$(cd terraform && terraform output -raw sfn_arn 2>/dev/null) || true
  fi
fi

if [[ -z "${SFN_ARN:-}" ]]; then
  echo -e "${RED}ERROR:${NC} SFN_ARN is not set."
  exit 1
fi

header "Simulating 3 failed Step Functions executions"
info "State machine: $SFN_ARN"
echo ""

# Each execution sends an invalid findingId that doesn't exist in DynamoDB.
# The SFN will try UpdateStatusRunning → fail on the DynamoDB update → ScanFailed.
for i in 1 2 3; do
  EXEC_NAME="alarm-test-$(date +%s)-${i}"
  INPUT=$(cat <<EOF
{
  "findingId": "alarm-test-fake-${i}",
  "timestamp": "2099-01-01T00:00:00.000Z",
  "scanType": "SAST",
  "s3UploadKey": "uploads/does-not-exist/source.zip"
}
EOF
)

  aws stepfunctions start-execution \
    --state-machine-arn "$SFN_ARN" \
    --name "$EXEC_NAME" \
    --input "$INPUT" \
    --query "executionArn" \
    --output text > /dev/null

  pass "Execution $i started: $EXEC_NAME"
  sleep 2
done

header "Next steps"
info "Wait 5-10 minutes for executions to fail and metrics to populate."
info "Then check:"
info "  1. AWS Console → CloudWatch → Alarms → unified-security-hub-dev-failed-scans"
info "     Should be in ALARM state."
info "  2. Check the SNS subscription email for the failure notification."
echo ""
info "To verify alarm state via CLI:"
info "  aws cloudwatch describe-alarms --alarm-names unified-security-hub-dev-failed-scans --query 'MetricAlarms[0].StateValue'"
echo ""