# Unified Security Hub — Testing Guide

## Known Values

| Resource | Value |
|---|---|
| API URL | `https://ys1euam2sb.execute-api.us-east-1.amazonaws.com/dev/scan-jobs` |
| API Key ID | `50qyvt34qf` |
| S3 Artifacts Bucket | `ush-artifacts-884298140443` |
| DynamoDB Table | `unified-security-hub-findings-dev` |
| ECS Cluster | `unified-security-hub` |
| SAST Log Group | `/ecs/security-hub-dev-sast` |
| Pentest Log Group | `/ecs/security-hub-dev-pentest` |
| Lambda Function | `unified-security-hub-api` |
| Step Functions | `unified-security-hub-scanner-dev` |

---

## Before Every Test Session

### 1. Refresh AWS credentials (expire every ~4 hours)
From Learner Lab → AWS Details → copy and export:
```bash
export AWS_ACCESS_KEY_ID=<your_key>
export AWS_SECRET_ACCESS_KEY=<your_secret>
export AWS_SESSION_TOKEN=<your_token>

# Verify
aws sts get-caller-identity
```

### 2. Set shell variables
```bash
API_URL="https://ys1euam2sb.execute-api.us-east-1.amazonaws.com/dev/scan-jobs"

API_KEY=$(aws apigateway get-api-key \
  --api-key 50qyvt34qf \
  --include-value \
  --query "value" --output text)

echo $API_KEY  # should be a long string, not "50qyvt34qf"
```

---

## Rebuild & Push Docker Images
> Required after any changes to `sast/backend/` or `pentest/backend/`

```bash
# From project root
cd sast/backend && npm install && cd ../..
cd pentest/backend && npm install && cd ../..
bash docs/script.sh
```

> Note: Script uses `--platform linux/amd64` — required for Apple Silicon Macs.

---

## Test SAST (Static Code Scan)

### Step 1 — Create job
```bash
RESPONSE=$(curl -s -X POST $API_URL \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"scanType": "SAST", "userId": "test-user"}')

echo $RESPONSE

FINDING_ID=$(echo $RESPONSE | python3 -c "import sys,json; print(json.load(sys.stdin)['findingId'])")
UPLOAD_URL=$(echo $RESPONSE | python3 -c "import sys,json; print(json.load(sys.stdin)['uploadUrl'])")
```

### Step 2 — Prepare and upload test file
```bash
echo "const password = 'hardcoded123'; eval(userInput);" > test.js
zip test.zip test.js

curl -X PUT "$UPLOAD_URL" \
  -H "Content-Type: application/zip" \
  --data-binary @test.zip
# No output = success
```

### Step 3 — Start scan
```bash
curl -X POST $API_URL/$FINDING_ID/start \
  -H "x-api-key: $API_KEY"
# Expected: {"findingId": "...", "status": "RUNNING"}
```

### Step 4 — Poll status (wait ~1-2 min)
```bash
curl -s $API_URL/$FINDING_ID -H "x-api-key: $API_KEY"
# Expected final: {"status": "COMPLETED", "severity": "HIGH", "s3ReportKey": "reports/.../report.json"}
```

### Step 5 — Download report
```bash
aws s3 cp s3://ush-artifacts-884298140443/reports/$FINDING_ID/report.json ./report.json
cat report.json
```

---

## Test Pentest (API Security Scan)

### Step 1 — Create job
```bash
RESPONSE=$(curl -s -X POST $API_URL \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"scanType": "PENTEST", "targetUrl": "https://httpbin.org", "userId": "test-user"}')

echo $RESPONSE

FINDING_ID=$(echo $RESPONSE | python3 -c "import sys,json; print(json.load(sys.stdin)['findingId'])")
```

### Step 2 — Start scan (no file upload needed)
```bash
curl -X POST $API_URL/$FINDING_ID/start \
  -H "x-api-key: $API_KEY"
```

### Step 3 — Poll status (wait ~2-3 min)
```bash
curl -s $API_URL/$FINDING_ID -H "x-api-key: $API_KEY"
```

### Step 4 — Download report
```bash
aws s3 cp s3://ush-artifacts-884298140443/reports/$FINDING_ID/report.json ./pentest-report.json
cat pentest-report.json
```

---

## List All Jobs
```bash
# All jobs
curl -s $API_URL -H "x-api-key: $API_KEY"

# Filter by type
curl -s "$API_URL?source=SAST" -H "x-api-key: $API_KEY"
curl -s "$API_URL?source=PENTEST" -H "x-api-key: $API_KEY"
```

---

## Debugging

### View container logs (CloudWatch)
```bash
aws logs tail /ecs/security-hub-dev-sast --follow
aws logs tail /ecs/security-hub-dev-pentest --follow
aws logs tail /aws/lambda/unified-security-hub-api --follow
```

### Check Step Functions execution
```
AWS Console → Step Functions → unified-security-hub-scanner-dev → Executions
```

### Check S3 contents
```bash
aws s3 ls s3://ush-artifacts-884298140443/uploads/ --recursive
aws s3 ls s3://ush-artifacts-884298140443/reports/ --recursive
```

### Check DynamoDB directly
```
AWS Console → DynamoDB → Tables → unified-security-hub-findings-dev → Explore items
```

---

## Re-deploy Infrastructure
```bash
cd terraform
terraform apply    # safe to run anytime — only changes what's different
```

## Update tfvars if Account ID changed
```bash
aws sts get-caller-identity --query Account --output text
# Update lab_role_arn in terraform/terraform.tfvars if different from 884298140443
```