# Unified Security Hub

A serverless AWS security scanning platform integrating SAST and API penetration testing tools. Built for CS6620 Cloud Computing.

## Team

| Name | GitHub | Role |
|------|--------|------|
| Aarushi Kaushik | [@aarushikaushikk](https://github.com/aarushikaushikk) | Data infra (DynamoDB, IAM), ECR, ECS cluster, S3, CloudWatch |
| Ran Zhao | [@whispergogogo](https://github.com/whispergogogo) | Docker images for SAST & Pentest scanners (Node.js), frontend |
| Junrui Ding | [@Rae99](https://github.com/Rae99) | Lambda APIs and observability |

## Architecture

```
                    ┌──────────────┐
                    │   S3 Frontend │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │  API Gateway  │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │    Lambda     │
                    └──┬───────┬───┘
                       │       │
              ┌────────▼┐  ┌──▼─────────┐
              │  SAST    │  │  Pentest   │
              │  (ECS    │  │  (ECS      │
              │  Fargate)│  │  Fargate)  │
              └────┬─────┘  └──┬─────────┘
                   │           │
            ┌──────▼───────────▼──────┐
            │       DynamoDB          │
            │   (Findings Table)      │
            └─────────────────────────┘
```

## AWS Services

- **ECS Fargate** — Runs SAST and Pentest scanner containers
- **ECR** — Stores Docker images (`security-hub-dev-sast`, `security-hub-dev-pentest`)
- **DynamoDB** — Stores security findings with GSIs for source, severity, and status queries
- **S3** — Artifacts bucket (scan reports) + frontend bucket (static website)
- **CloudWatch** — Log groups for scanner containers (14-day retention)
- **VPC** — Private subnets for Fargate tasks, NAT gateway for outbound access
- **Step Functions** — Orchestrates scan workflows
- **SNS** — Email notifications for scan results
- **API Gateway + Lambda** — Backend API

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

From Learner Lab → AWS Details, copy and export your credentials:

```bash
export AWS_ACCESS_KEY_ID=<your_key>
export AWS_SECRET_ACCESS_KEY=<your_secret>
export AWS_SESSION_TOKEN=<your_token>
export AWS_DEFAULT_REGION=us-east-1
```

Verify:

```bash
aws sts get-caller-identity
```

> **Note:** Learner Lab credentials expire every ~4 hours. Re-export when they expire.

### 3. Provision all infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

This single command creates everything: VPC, subnets, NAT gateway, DynamoDB table, ECR repos, ECS cluster, CloudWatch log groups, and S3 buckets.

Verify with:

```bash
terraform output
```

### 4. Build & push Docker images

Make sure Docker Desktop is running, then from the repo root:

```bash
bash docs/script.sh
```

This builds Node.js images for both scanners and pushes them to ECR.

Verify:

```bash
aws ecr list-images --repository-name security-hub-dev-sast --output table
aws ecr list-images --repository-name security-hub-dev-pentest --output table
```

### 5. Register ECS task definitions

```bash
aws ecs register-task-definition --cli-input-json file://infra/task-definition-sast.json
aws ecs register-task-definition --cli-input-json file://infra/task-definition-pentest.json
```

## Project Structure

```
unified-security-hub/
├── sast/
│   └── backend/
│       ├── server.js          # Express server
│       ├── scanner.js         # SAST scanning logic
│       ├── package.json
│       └── Dockerfile         # node:18-alpine based
├── pentest/
│   └── backend/
│       ├── server.js          # Express server
│       ├── tester.js          # Pentest logic
│       ├── test-target.js     # Test target server
│       ├── package.json
│       └── Dockerfile         # node:18-alpine + nmap
├── terraform/
│   ├── main.tf                # Root module — calls all child modules
│   ├── provider.tf            # AWS provider config
│   ├── variables.tf           # All input variables
│   ├── outputs.tf             # All outputs
│   ├── terraform.tfvars       # Default values
│   └── modules/
│       ├── vpc/               # USH-5: VPC, subnets, NAT, endpoints
│       ├── dynamodb/          # USH-1: Findings table + 3 GSIs
│       ├── ecr/               # USH-3: SAST + Pentest repos
│       ├── ecs/               # USH-4: Cluster + log groups
│       └── s3/                # USH-4: Artifacts + frontend buckets
├── infra/
│   ├── task-definition-sast.json
│   └── task-definition-pentest.json
├── docs/
│   ├── ecr-setup.md           # ECR setup guide
│   └── script.sh              # Build & push images script
└── README.md
```

## Terraform Modules

| Module | Ticket | What it creates |
|--------|--------|-----------------|
| `vpc` | USH-5 | VPC, 1 public + 2 private subnets, IGW, NAT, route tables, S3 + DynamoDB VPC endpoints |
| `dynamodb` | USH-1 | Findings table (PK: `finding_id`, SK: `timestamp`) + SourceIndex, SeverityIndex, StatusIndex GSIs |
| `ecr` | USH-3 | `security-hub-dev-sast` and `security-hub-dev-pentest` repos with scan-on-push |
| `ecs` | USH-4 | `unified-security-hub` cluster (Container Insights enabled) + 2 CloudWatch log groups (14-day retention) |
| `s3` | USH-4 | Artifacts bucket (versioning, public access blocked, 90-day lifecycle on `reports/`) + frontend bucket (static website) |

## Scanner Images

| Scanner | Base Image | Tools | Health Check | Port |
|---------|-----------|-------|-------------|------|
| SAST | `node:18-alpine` | Node.js/Express | `GET /health` | 3000 |
| Pentest | `node:18-alpine` | Node.js/Express, nmap, nmap-scripts | `GET /health` | 3000 |

## Learner Lab Tips

- **Credentials expire** every ~4 hours — re-export from AWS Details panel
- **Use LabRole** for all IAM needs — you cannot create custom IAM roles
- **Region:** Always `us-east-1`
- **Docker:** Use your local Mac with Docker Desktop (Learner Lab terminal doesn't have Docker)
- **Terraform state:** Don't commit `.tfstate` files — they're in `.gitignore`
- **Container Insights:** Use `--include SETTINGS` flag with `aws ecs describe-clusters` to see settings
