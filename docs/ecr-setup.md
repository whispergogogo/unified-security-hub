# USH-3: ECR Repositories + Push Base Images

## Overview
Two ECR repositories store the Docker images for our ECS Fargate scan tasks:
- **security-hub-dev-sast** — Static Application Security Testing scanner
- **security-hub-dev-pentest** — Penetration Testing scanner

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
docker build -t security-hub-dev-sast ./sast-scanner
docker build -t security-hub-dev-pentest ./pentest-scanner
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
Use `scripts/build-and-push.sh` to run all steps automatically.

## Scanner Details

### SAST Scanner
- **Base image:** python:3.11-slim
- **Tools:** semgrep, boto3
- **Purpose:** Downloads source code from S3, runs semgrep, uploads report to S3

### Pentest Scanner
- **Base image:** python:3.11-slim
- **Tools:** nmap, curl, boto3, requests
- **Purpose:** Scans target URL, uploads report to S3

## Notes
- Learner Lab credentials expire every ~4 hours — re-export before pushing
- Docker Desktop must be running on your local machine
- The `--username AWS` is literal — do not replace with your name
- Never commit AWS credentials to the repo

