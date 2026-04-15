# Unified Security Hub — Frontend Testing Guide

## Full Setup (Start Here)

### Step 1 — Export AWS credentials
From Learner Lab → AWS Details → copy and export:
```bash
export AWS_ACCESS_KEY_ID=<your_key>
export AWS_SECRET_ACCESS_KEY=<your_secret>
export AWS_SESSION_TOKEN=<your_token>

# Verify — Account should be your lab account ID
aws sts get-caller-identity
```

> Credentials expire every ~4 hours. If you see `UnrecognizedClientException`, re-export.

### Step 2 — Check lab_role_arn
If the Account ID changed since last session, update `terraform/terraform.tfvars`:
```
lab_role_arn = "arn:aws:iam::<ACCOUNT_ID>:role/LabRole"
```

### Step 3 — Package Lambda
```bash
cd api/lambda
npm install
zip -r function.zip .
cd ../..
```

### Step 4 — Terraform apply
```bash
cd terraform
terraform init   # only needed first time or after module changes
terraform apply
```

### Step 5 — Build & push Docker images
```bash
# From project root
bash docs/script.sh
```

> Required after any changes to `sast/backend/`, `pentest/backend/`, or `Dockerfile.test-target`.
> Uses `--platform linux/amd64` — required for Apple Silicon Macs.

### Step 6 — Set frontend environment variables
```bash
cd terracd form

API_KEY=$(aws apigateway get-api-key \
  --api-key $(terraform output -raw api_key_id) \
  --include-value \
  --query "value" --output text)

cat > ../frontend/.env << EOF
VITE_USE_MOCK=false
VITE_API_URL="$(terraform output -raw api_url)"
VITE_API_KEY="$API_KEY"
EOF

cd ..
```

### Step 7 — Start frontend locally
```bash
cd frontend
npm install   # only needed first time
npm run dev
# Open http://localhost:<your port>
```

---

## Test 1 — Dashboard Page

1. Open the app — sidebar shows **Dashboard** and **New Scan**
2. Summary cards show: Total Scans / Completed / Running / Failed
3. Job list table loads (empty if no scans yet)
4. Jobs auto-refresh every 10 seconds

**Expected:** Table loads without errors. Status badges are color-coded.

---

## Test 2 — SAST Scan

1. Click **New Scan** in the sidebar → **SAST** tab
2. Prepare test file:
```bash
# test-sast.js should be in project root
zip test-sast.zip test-sast.js
```
3. Drop or select `test-sast.zip` in the dropzone
4. Click **Start Scan**
5. Step indicator shows: `Create job → Upload zip → Start scan`
6. On success: "Scan started!" screen with **View Dashboard** button
7. Click **View Dashboard** — job appears with status `Running`
8. Wait ~1-2 min — status changes to `Completed`
9. Click the row → Report Detail page opens

**Expected report:** 36 findings, severity HIGH.

---

## Test 3 — Pentest: Public API

1. Click **New Scan** → **Pentest** tab
2. Click **Quick fill: restful-api.dev**
3. Click **Start Pentest**
4. Wait ~2-3 min — status changes to `Completed`
5. Click the row → Report Detail page opens

**Expected report:** 6 tests, severity HIGH (SQL Injection, Rate Limiting, Security Headers, Sensitive Data Exposure fail).

---

## Test 4 — Pentest: Test Target (Intentionally Vulnerable API)

### The test-target runs as a persistent ECS Service — no manual run-task needed
```bash
CLUSTER=$(cd terraform && terraform output -raw cluster_name)

TASK_ARN=$(aws ecs list-tasks \
  --cluster $CLUSTER \
  --service-name security-hub-dev-test-target \
  --region us-east-1 \
  --query "taskArns[0]" \
  --output text)

sleep 30

ENI_ID=$(aws ecs describe-tasks \
  --cluster $CLUSTER --tasks $TASK_ARN \
  --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" \
  --output text)

PUBLIC_IP=$(aws ec2 describe-network-interfaces \
  --network-interface-ids $ENI_ID \
  --query "NetworkInterfaces[0].Association.PublicIp" \
  --output text)

echo "Test-Target URL: http://$PUBLIC_IP:4000"
```

### Run pentest via frontend
1. Click **New Scan** → **Pentest** tab
2. Enter `http://<PUBLIC_IP>:4000` in the URL field
3. Click **Start Pentest**
4. Wait ~2-3 min — check Dashboard for status


---

## Test 5 — Report Detail Page

1. From Dashboard, click any **Completed** job row
2. Report Detail page shows:
   - Job metadata (type, scanned at, target URL if pentest)
   - Summary pills (High / Medium / Low for SAST, Pass / Fail / Warning for Pentest)
   - Findings grouped by severity (SAST) or test results list (Pentest)
   - Click any finding to expand — shows code evidence and recommendation
3. **Download raw JSON** link at the bottom

---

## Deploy Frontend to S3

After verifying locally:

```bash
cd frontend
npm run build

FRONTEND_BUCKET=$(cd ../terraform && terraform output -raw frontend_bucket)
aws s3 sync dist/ s3://$FRONTEND_BUCKET --delete

echo "Live at: http://$FRONTEND_BUCKET.s3-website-us-east-1.amazonaws.com"
```

> Re-run `npm run build` and `aws s3 sync` any time frontend code changes.
> No `terraform apply` needed for frontend-only changes.

---

## Debugging

| Problem | Check |
|---|---|
| `UnrecognizedClientException` | Re-export AWS credentials from Learner Lab |
| Blank page / CORS errors | Open browser DevTools → Console |
| Jobs list empty | Check `VITE_API_KEY` is the key value, not the key ID |
| Scan stuck at Running | `aws logs tail /ecs/security-hub-dev-sast --follow` |
| Report page shows "not available" | Scan may still be running — wait and refresh |
| S3 page returns 403 | Run `terraform apply` — frontend bucket policy may not be applied |
| ECS task fails immediately | Check ECR has images: `bash docs/script.sh` |