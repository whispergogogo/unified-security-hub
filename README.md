# Unified Security Hub

A serverless AWS security scanning platform integrating SAST and API penetration testing tools. Built for CS6620 Cloud Computing.

## Team

| Name | GitHub |
|------|--------|
| Aarushi Kaushik | [@aarushikaushikk](https://github.com/aarushikaushikk) |
| Ran Zhao | [@whispergogogo](https://github.com/whispergogogo) |
| Junrui Ding | [@Rae99](https://github.com/Rae99) |

## Architecture

```
                    ┌──────────────┐
                    │  S3 Frontend  │
                    │  (React SPA)  │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │  API Gateway  │
                    │  (API Key)    │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │    Lambda     │
                    │  createJob    │
                    │  listJobs     │
                    │  getJob       │
                    │  startScan    │
                    │  getReport    │
                    └──────┬───────┘
                           │
                    ┌──────▼────────┐
                    │ Step Functions │
                    │  State Machine │
                    └──┬─────────┬──┘
                       │         │
              ┌────────▼─┐  ┌───▼────────┐
              │   SAST    │  │  Pentest   │
              │ (Fargate) │  │ (Fargate)  │
              │ private   │  │ private    │
              │ subnet    │  │ subnet     │
              └────┬──────┘  └──┬─────────┘
                   │            │
          ┌────────▼────────────▼──────┐
          │  S3 Artifacts Bucket       │
          │  uploads/ + reports/       │
          │  DynamoDB Findings Table   │
          └────────────────────────────┘

              ┌─────────────────────┐
              │  Test Target API    │
              │  (Fargate, public   │
              │   subnet, port 4000)│
              └─────────────────────┘
```

## AWS Services

| Service | Purpose |
|---|---|
| **API Gateway** | Public HTTPS entrypoint with API key authentication |
| **Lambda** | Request handlers: `createJob`, `listJobs`, `getJob`, `startScan`, `getReport` |
| **Step Functions** | Scan pipeline orchestration with retries, timeouts, and parallel branching |
| **ECS Fargate** | Runs SAST, Pentest, and Test-Target containers |
| **ECR** | Stores Docker images for all three containers |
| **DynamoDB** | Findings table with GSIs for source, severity, and status queries |
| **S3** | Artifacts bucket (`uploads/`, `reports/`) + frontend static website |
| **CloudWatch** | Log groups for all containers (14-day retention) |
| **VPC** | Private subnets for scanner tasks, public subnet for test-target, NAT gateway |
| **SNS** | Alerts topic for high-severity scan results |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) (v1.5+)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) (v2)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (for building scanner images)
- AWS Academy Learner Lab account

## Getting Started

### 1. Clone the repo

```bash
git clone https://github.com/whispergogogo/unified-security-hub.git
cd unified-security-hub
```

### 2. Set AWS credentials

From Learner Lab → AWS Details, copy and export:

```bash
export AWS_ACCESS_KEY_ID=<your_key>
export AWS_SECRET_ACCESS_KEY=<your_secret>
export AWS_SESSION_TOKEN=<your_token>
export AWS_DEFAULT_REGION=us-east-1

# Verify
aws sts get-caller-identity
```

> **Note:** Learner Lab credentials expire every ~4 hours. Re-export when they expire.
> After each Lab session reset, the account ID may change — update `lab_role_arn` in `terraform/terraform.tfvars` before re-applying.

### 3. Package the Lambda function

```bash
cd api/lambda
npm install
zip -r function.zip .
cd ../..
```

### 4. Provision all infrastructure

```bash
cd terraform
terraform init
terraform apply
```

This creates: VPC, subnets, NAT gateway, DynamoDB, ECR repos, ECS cluster, CloudWatch log groups, S3 buckets, Lambda, API Gateway, and Step Functions state machine.

```bash
# View all output values (API URL, bucket names, ARNs, etc.)
terraform output
```

### 5. Build & push Docker images

Make sure Docker Desktop is running, then from the repo root:

```bash
bash docs/script.sh
```

This builds three images (`sast`, `pentest`, `test-target`) with `--platform linux/amd64` and pushes them to ECR.

```bash
# Verify images were pushed (repo names from terraform output)
aws ecr list-images --repository-name $(cd terraform && terraform output -raw sast_repo_url | cut -d'/' -f2) --output table
aws ecr list-images --repository-name $(cd terraform && terraform output -raw pentest_repo_url | cut -d'/' -f2) --output table
aws ecr list-images --repository-name $(cd terraform && terraform output -raw test_target_repo_url | cut -d'/' -f2) --output table
```

### 6. Deploy the frontend

```bash
cd frontend
npm install
npm run build
```

Then upload the `dist/` folder to the S3 frontend bucket:

```bash
aws s3 sync dist/ s3://$(cd ../terraform && terraform output -raw frontend_bucket_name) --delete
```

For detailed testing instructions, see [testing.md](testing.md) and [frontend-testing.md](frontend-testing.md).

## Project Structure

```
unified-security-hub/
├── api/
│   └── lambda/
│       ├── index.mjs          # Lambda handler (createJob, listJobs, getJob, startScan, getReport)
│       └── package.json
├── sast/
│   └── backend/
│       ├── index.js           # One-shot ECS entry point (download zip → scan → upload report → exit)
│       ├── server.js          # Express server (local development only)
│       ├── scanner.js         # SAST scanning logic
│       ├── package.json
│       └── Dockerfile         # node:18-alpine + unzip, CMD: node index.js
├── pentest/
│   └── backend/
│       ├── index.js           # One-shot ECS entry point (run tests → upload report → exit)
│       ├── server.js          # Express server (local development only)
│       ├── tester.js          # Pentest logic
│       ├── test-target.js     # Intentionally vulnerable target API
│       ├── package.json
│       ├── Dockerfile         # node:18-alpine + nmap, CMD: node index.js
│       └── Dockerfile.test-target  # node:18-alpine, CMD: node test-target.js, EXPOSE 4000
├── frontend/
│   ├── src/
│   │   ├── App.jsx            # Router — /dashboard, /scan/new, /scan/:id
│   │   ├── main.jsx           # Entry point
│   │   ├── api/client.js      # API client for Lambda endpoints
│   │   ├── components/        # Layout, StatusBadge, SeverityBadge
│   │   └── pages/             # Dashboard, NewScan, ReportDetail
│   ├── package.json           # React 18, React Router 6, Vite, Tailwind
│   └── vite.config.js
├── terraform/
│   ├── main.tf                # Root module — wires all child modules together
│   ├── provider.tf            # AWS provider config
│   ├── variables.tf           # All input variables
│   ├── outputs.tf             # All outputs
│   ├── terraform.tfvars       # Environment values (lab_role_arn, etc.)
│   └── modules/
│       ├── VPC/               # VPC, subnets, IGW, NAT, route tables, VPC endpoints
│       ├── dynamodb/          # Findings table + 3 GSIs
│       ├── ecr/               # SAST, Pentest, Test-Target repos
│       ├── ecs/               # ECS cluster + CloudWatch log groups
│       ├── s3/                # Artifacts + frontend buckets
│       ├── lambda/            # Lambda function + API Gateway + API key
│       ├── sfn/               # Step Functions state machine + SNS topic
│       └── tasks/             # ECS task definitions + security groups
├── docs/
│   ├── script.sh              # Build & push all three Docker images to ECR
│   └── ecr-setup.md           # ECR setup reference
├── testing.md                 # End-to-end testing guide
├── frontend-testing.md        # Frontend testing guide
└── README.md
```

## Terraform Modules

| Module | What it creates |
|--------|-----------------|
| `VPC` | VPC, 1 public + 2 private subnets, IGW, NAT, route tables, S3 + DynamoDB VPC Gateway endpoints |
| `dynamodb` | Findings table (`finding_id` PK, `timestamp` SK) + SourceIndex, SeverityIndex, StatusIndex GSIs |
| `ecr` | `security-hub-dev-sast`, `security-hub-dev-pentest`, `security-hub-dev-test-target` repos |
| `ecs` | `unified-security-hub` ECS cluster (Container Insights on) + 3 CloudWatch log groups |
| `s3` | Artifacts bucket (versioning, 90-day lifecycle on `reports/`) + frontend bucket (static website) |
| `lambda` | Lambda function + REST API Gateway + API key + usage plan |
| `sfn` | Step Functions state machine + SNS alerts topic |
| `tasks` | SAST, Pentest, Test-Target task definitions + ECS security groups |

## Container Images

| Image | Base | Entry point | Subnet | Notes |
|---|---|---|---|---|
| `sast` | `node:18-alpine` | `node index.js` | Private | One-shot: download zip → scan → upload report → exit |
| `pentest` | `node:18-alpine` + nmap | `node index.js` | Private | One-shot: run tests → upload report → exit |
| `test-target` | `node:18-alpine` | `node test-target.js` | **Public** | Long-running server, port 4000, intentionally vulnerable |

## Scan Flow

```
POST /scan-jobs              → Lambda createJob  → DynamoDB (PENDING) + S3 pre-signed upload URL
PUT  <pre-signed-url>        → S3 upload (SAST only)
POST /scan-jobs/:id/start    → Lambda startScan  → Step Functions execution starts
                             → Step Functions → ECS runTask.sync (SAST and/or Pentest in parallel)
                             → Container runs → writes report to S3 + severity to DynamoDB
                             → Step Functions → DynamoDB (COMPLETED) → SNS (if HIGH/CRITICAL)
GET  /scan-jobs/:id          → Lambda getJob     → DynamoDB read
GET  /scan-jobs/:id/report   → Lambda getReport  → DynamoDB read → S3 fetch → report JSON
```

## DynamoDB Schema

| Attribute | Type | Description |
|---|---|---|
| `finding_id` (PK) | String | UUID — unique job identifier |
| `timestamp` (SK) | String | ISO-8601 creation time |
| `source` | String | `SAST` or `PENTEST` |
| `status` | String | `PENDING` → `RUNNING` → `COMPLETED` / `FAILED` |
| `severity` | String | `HIGH` / `MEDIUM` / `LOW` / `INFO` — written by container after scan |
| `userId` | String | API caller identifier |
| `s3UploadKey` | String | S3 key for uploaded zip (SAST only) |
| `s3ReportKey` | String | S3 key for result report JSON |
| `targetUrl` | String | Target URL (Pentest only) |
| `errorMessage` | String | Error detail if status is `FAILED` |

## Learner Lab Tips

- **Credentials expire** every ~4 hours — re-export from AWS Details panel
- **Account ID may change** after Lab reset — run `aws sts get-caller-identity` and update `lab_role_arn` in `terraform.tfvars` if needed
- **Use LabRole** for all IAM — custom IAM roles cannot be created
- **Region:** Always `us-east-1`
- **Docker:** Build on your local Mac with Docker Desktop — Learner Lab terminal has no Docker
- **Apple Silicon:** `docs/script.sh` uses `--platform linux/amd64` — required for ECS Fargate
- **Terraform state:** `.tfstate` files are gitignored — do not commit them
- **test-target:** Stop the ECS task after testing to avoid unnecessary charges
