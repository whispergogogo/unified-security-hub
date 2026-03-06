# USH-3: ECR Repositories + Push Base Images
## Overview
Two ECR repositories store the Docker images for our ECS Fargate scan tasks:
- **security-hub-dev-sast** — Static Application Security Testing scanner
- **security-hub-dev-pentest** — Penetration Testing scanner

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
