# USH-3: ECR Repositories + Push Base Images
## Overview
Two ECR repositories store the Docker images for our ECS Fargate scan tasks:
- **security-hub-dev-sast** — Static Application Security Testing scanner
- **security-hub-dev-pentest** — Penetration Testing scanner

Both repositories are provisioned via Terraform (`terraform/modules/ecr/`) with scan-on-push enabled.

Both repositories are provisioned via Terraform (`terraform/modules/ecr/`) with scan-on-push enabled.

## ECR Image URIs
```
<AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/security-hub-dev-sast:latest
<AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/security-hub-dev-pentest:latest
```

## AWS Details
- **Region:** us-east-1
- **IAM Role:** LabRole (Learner Lab)

## How to Rebuild & Push Images

### Prerequisites
- Docker Desktop installed and running
- AWS CLI installed (`brew install awscli` on Mac)

### 1. Set AWS Credentials
Go to Learner Lab → AWS Details → copy credentials:
```bash
export AWS_ACCESS_KEY_ID=<from lab>
export AWS_SECRET_ACCESS_KEY=<from lab>
export AWS_SESSION_TOKEN=<from lab>
export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
```

### 2. Login to ECR
```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
```

### 3. Build Images
```bash
docker build -t security-hub-dev-sast ./sast/backend
docker build -t security-hub-dev-pentest ./pentest/backend
```

### 4. Tag Images
```bash
docker tag security-hub-dev-sast:latest $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/security-hub-dev-sast:latest
docker tag security-hub-dev-pentest:latest $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/security-hub-dev-pentest:latest
```

### 5. Push to ECR
```bash
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/security-hub-dev-sast:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/security-hub-dev-pentest:latest
```

### 6. Verify
```bash
aws ecr list-images --repository-name security-hub-dev-sast --region us-east-1
aws ecr list-images --repository-name security-hub-dev-pentest --region us-east-1
```

## Quick Build Script
Use `docs/script.sh` to run all steps automatically:
```bash
bash docs/script.sh
```

## Scanner Details

### SAST Scanner
- **Base image:** node:18-alpine
- **Dockerfile:** `sast/backend/Dockerfile`
- **Tools:** Node.js/Express, semgrep
- **Health check:** `GET /health` on port 3000
- **Purpose:** Scans source code for security vulnerabilities, uploads report to S3

### Pentest Scanner
- **Base image:** node:18-alpine
- **Dockerfile:** `pentest/backend/Dockerfile`
- **Tools:** Node.js/Express, nmap, nmap-scripts
- **Health check:** `GET /health` on port 3000
- **Purpose:** Scans target URL/API for vulnerabilities, uploads report to S3

## Infrastructure as Code
ECR repositories are managed via Terraform in the root module:
```bash
cd terraform
terraform init
terraform apply
```
This creates both ECR repos along with all other infrastructure (VPC, DynamoDB, ECS cluster, S3 buckets, CloudWatch log groups).

## Notes
- Learner Lab credentials expire every ~4 hours — re-export before pushing
- Docker Desktop must be running on your local machine
- The `--username AWS` is literal — do not replace with your name
- Never commit AWS credentials to the repo
- Old Python-based images have been replaced with Node.js — do not use `sast-scanner/` or `pentest-scanner/` paths
