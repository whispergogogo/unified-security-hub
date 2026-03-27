#!/bin/bash
set -euo pipefail

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"
ECR_BASE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "=== Logging into ECR ==="
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${ECR_BASE}

echo "=== Building SAST scanner (linux/amd64) ==="
docker build --platform linux/amd64 -t security-hub-dev-sast:latest ./sast/backend/

echo "=== Tagging & pushing SAST ==="
docker tag security-hub-dev-sast:latest ${ECR_BASE}/security-hub-dev-sast:latest
docker push ${ECR_BASE}/security-hub-dev-sast:latest

echo "=== Building Pentest scanner (linux/amd64) ==="
docker build --platform linux/amd64 -t security-hub-dev-pentest:latest ./pentest/backend/

echo "=== Tagging & pushing Pentest ==="
docker tag security-hub-dev-pentest:latest ${ECR_BASE}/security-hub-dev-pentest:latest
docker push ${ECR_BASE}/security-hub-dev-pentest:latest

echo "=== Building Test Target (linux/amd64) ==="
docker build --platform linux/amd64 \
  -f ./pentest/backend/Dockerfile.test-target \
  -t security-hub-dev-test-target:latest \
  ./pentest/backend/

echo "=== Tagging & pushing Test Target ==="
docker tag security-hub-dev-test-target:latest ${ECR_BASE}/security-hub-dev-test-target:latest
docker push ${ECR_BASE}/security-hub-dev-test-target:latest

echo "=== Done! ==="
echo "  ${ECR_BASE}/security-hub-dev-sast:latest"
echo "  ${ECR_BASE}/security-hub-dev-pentest:latest"
echo "  ${ECR_BASE}/security-hub-dev-test-target:latest"