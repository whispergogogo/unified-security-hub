# Unified Security Hub — Testing Guide

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

> If the account ID has changed since the last session, update `lab_role_arn` in
> `terraform/terraform.tfvars` and re-run `terraform apply` before testing.

### 2. Set shell variables from Terraform outputs

Run this block once at the start of each session — all commands below depend on these variables.

```bash
cd terraform

API_URL=$(terraform output -raw api_url)
API_KEY_ID=$(terraform output -raw api_key_id)
ARTIFACTS_BUCKET=$(terraform output -raw artifacts_bucket)
CLUSTER=$(terraform output -raw cluster_name)
PUBLIC_SUBNET=$(terraform output -raw public_subnet_id)
TEST_TARGET_SG=$(terraform output -raw test_target_security_group_id)
TEST_TARGET_TASK_DEF_ARN=$(terraform output -raw test_target_task_definition_arn)
# Use only the family name (without revision) for run-task
TEST_TARGET_TASK_DEF=$(echo $TEST_TARGET_TASK_DEF_ARN | awk -F'/' '{print $2}' | awk -F':' '{print $1}')

cd ..

# Fetch the actual API key value (not the ID)
API_KEY=$(aws apigateway get-api-key \
  --api-key $API_KEY_ID \
  --include-value \
  --query "value" --output text)

# Verify — should be a long random string, not the key ID
echo "API_URL: $API_URL"
echo "API_KEY: $API_KEY"
```

---

## Rebuild & Push Docker Images

> Required after any changes to `sast/backend/`, `pentest/backend/`, or `Dockerfile.test-target`

```bash
# From project root
cd sast/backend && npm install && cd ../..
cd pentest/backend && npm install && cd ../..
bash docs/script.sh
```

> Script uses `--platform linux/amd64` — required for Apple Silicon Macs.

---

## Test SAST (Static Code Scan)

Uses the teacher-provided `test-sast.js` which contains 11 intentional vulnerability types.

### Step 1 — Create job and get upload URL

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
# test-sast.js should be in the project root
zip test-sast.zip test-sast.js

curl -X PUT "$UPLOAD_URL" \
  -H "Content-Type: application/zip" \
  --data-binary @test-sast.zip
# No output = upload succeeded
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
# Expected: {"status": "COMPLETED", "severity": "HIGH", "s3ReportKey": "reports/.../report.json"}
```

### Step 5 — Download report

```bash
aws s3 cp s3://$ARTIFACTS_BUCKET/reports/$FINDING_ID/report.json ./sast-report.json
cat sast-report.json
```

**Expected:** 36 findings, severity HIGH, covering HARDCODED_SECRET, SQL_INJECTION, NOSQL_INJECTION, XSS, PATH_TRAVERSAL, INSECURE_FUNCTION, INSECURE_RANDOM, SENSITIVE_DATA_LOG, WEAK_CRYPTO, SECURITY_TODO, HARDCODED_IP.

---

## Test Pentest — Method 1: Public API (`restful-api.dev`)

No extra setup needed. Tests against a real public REST API.

### Step 1 — Create and start job

```bash
RESPONSE=$(curl -s -X POST $API_URL \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"scanType": "PENTEST", "targetUrl": "https://restful-api.dev", "userId": "test-user"}')

echo $RESPONSE

FINDING_ID=$(echo $RESPONSE | python3 -c "import sys,json; print(json.load(sys.stdin)['findingId'])")

curl -X POST $API_URL/$FINDING_ID/start \
  -H "x-api-key: $API_KEY"
```

### Step 2 — Poll status (wait ~2-3 min)

```bash
curl -s $API_URL/$FINDING_ID -H "x-api-key: $API_KEY"
```

### Step 3 — Download report

```bash
aws s3 cp s3://$ARTIFACTS_BUCKET/reports/$FINDING_ID/report.json ./pentest-restful-report.json
cat pentest-restful-report.json
```

---

## Test Pentest — Method 2: Test-Target (Intentionally Vulnerable API)

Uses the teacher-provided `test-target.js` deployed as a long-running Fargate service in the public subnet.

### Step 1 — Start the test-target ECS task

```bash
TASK_ARN=$(aws ecs run-task \
  --cluster $CLUSTER \
  --task-definition $TEST_TARGET_TASK_DEF \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$PUBLIC_SUBNET],securityGroups=[$TEST_TARGET_SG],assignPublicIp=ENABLED}" \
  --region us-east-1 \
  --query "tasks[0].taskArn" \
  --output text)

echo "Task ARN: $TASK_ARN"
```

### Step 2 — Get public IP (wait ~30 seconds for container to start)

```bash
sleep 30

ENI_ID=$(aws ecs describe-tasks \
  --cluster $CLUSTER \
  --tasks $TASK_ARN \
  --region us-east-1 \
  --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" \
  --output text)

PUBLIC_IP=$(aws ec2 describe-network-interfaces \
  --network-interface-ids $ENI_ID \
  --query "NetworkInterfaces[0].Association.PublicIp" \
  --output text)

echo "Test-Target IP: $PUBLIC_IP"
```

### Step 3 — Create and start pentest job

```bash
RESPONSE=$(curl -s -X POST $API_URL \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"scanType\": \"PENTEST\", \"targetUrl\": \"http://$PUBLIC_IP:4000\", \"userId\": \"test-user\"}")

echo $RESPONSE

FINDING_ID=$(echo $RESPONSE | python3 -c "import sys,json; print(json.load(sys.stdin)['findingId'])")

curl -X POST $API_URL/$FINDING_ID/start \
  -H "x-api-key: $API_KEY"
```

### Step 4 — Poll status (wait ~2-3 min)

```bash
curl -s $API_URL/$FINDING_ID -H "x-api-key: $API_KEY"
```

### Step 5 — Download report

```bash
aws s3 cp s3://$ARTIFACTS_BUCKET/reports/$FINDING_ID/report.json ./pentest-target-report.json
cat pentest-target-report.json
```

### Step 6 — Stop test-target when done (avoid charges)

```bash
aws ecs stop-task \
  --cluster $CLUSTER \
  --task $TASK_ARN \
  --region us-east-1
```

---

## List All Jobs

```bash
# All jobs
curl -s $API_URL -H "x-api-key: $API_KEY"

# Filter by scan type
curl -s "$API_URL?source=SAST" -H "x-api-key: $API_KEY"
curl -s "$API_URL?source=PENTEST" -H "x-api-key: $API_KEY"
```

---

## Debugging

### View container logs (CloudWatch)

```bash
SAST_LOG=$(cd terraform && terraform output -raw sast_log_group)
PENTEST_LOG=$(cd terraform && terraform output -raw pentest_log_group)
LAMBDA_FN=$(cd terraform && terraform output -raw lambda_function_name)

aws logs tail $SAST_LOG --follow
aws logs tail $PENTEST_LOG --follow
aws logs tail /aws/lambda/$LAMBDA_FN --follow
```

### Check Step Functions execution

```
AWS Console → Step Functions → State machines → (name from: terraform output sfn_arn) → Executions
```

Click on an execution to see the live state machine diagram and each state's input/output.

### Check S3 contents

```bash
aws s3 ls s3://$ARTIFACTS_BUCKET/uploads/ --recursive
aws s3 ls s3://$ARTIFACTS_BUCKET/reports/ --recursive
```

### Check DynamoDB directly

```bash
TABLE=$(cd terraform && terraform output -raw dynamodb_table_name)
# AWS Console → DynamoDB → Tables → $TABLE → Explore items
echo "Table name: $TABLE"
```

### Common failure reasons

| Symptom | Likely cause | Fix |
|---|---|---|
| `CannotPullContainerError` platform mismatch | Image built for wrong arch | Rebuild with `--platform linux/amd64` via `docs/script.sh` |
| Step Functions `$.findingId not found` | `ResultPath` missing on RunTask state | Verify `sfn.tf` has `ResultPath = "$.taskResult"` on both RunTask states |
| `Forbidden` on API call | Wrong or empty `$API_KEY` | Re-run Step 2 of "Before Every Test Session" |
| `Role is not valid` on terraform apply | `lab_role_arn` account ID stale | Run `aws sts get-caller-identity`, update `terraform.tfvars`, re-apply |
| Step Functions `$.severity not found` | Severity not in execution context | `GetJobResult` state reads it back from DynamoDB after container exits |

---

## After Learner Lab Session Reset

```bash
# 1. Export new credentials (from Learner Lab → AWS Details)

# 2. Check if account ID changed
aws sts get-caller-identity --query Account --output text

# 3. If changed, update terraform/terraform.tfvars:
#    lab_role_arn = "arn:aws:iam::<NEW-ACCOUNT-ID>:role/LabRole"

# 4. Re-apply infrastructure (only changed resources are updated)
cd terraform && terraform apply && cd ..

# 5. Rebuild and push Docker images
bash docs/script.sh

# 6. Re-run Step 2 "Set shell variables" above
```