variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "unified-security-hub"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# ==============================================================
# VPC variables
# ==============================================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet (NAT Gateway)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_a_cidr" {
  description = "CIDR block for private subnet A (SAST Fargate)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_b_cidr" {
  description = "CIDR block for private subnet B (Pentest Fargate)"
  type        = string
  default     = "10.0.3.0/24"
}

variable "availability_zones" {
  description = "List of AZs — [public + private-A, private-B]"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# ==============================================================
# ECS variables
# ==============================================================

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
  default     = "unified-security-hub"
}

variable "project_prefix" {
  description = "Prefix for ECR repos, log groups, etc."
  type        = string
  default     = "security-hub-dev"
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days"
  type        = number
  default     = 14
}

# ==============================================================
# S3 variables
# ==============================================================

variable "artifacts_bucket_prefix" {
  description = "Prefix for the artifacts S3 bucket"
  type        = string
  default     = "ush-artifacts"
}

variable "frontend_bucket_prefix" {
  description = "Prefix for the frontend S3 bucket"
  type        = string
  default     = "ush-frontend"
}

variable "reports_expiry_days" {
  description = "Lifecycle expiry days for reports/ prefix"
  type        = number
  default     = 90
}

# ==============================================================
# Lambda + API Gateway variables (added by Junrui)
# ==============================================================

variable "sfn_arn" {
  description = "Step Functions ARN — set to 'placeholder' until Step Functions is created"
  type        = string
  default     = "placeholder"
}

variable "lambda_zip_path" {
  description = "Path to the Lambda function zip file"
  type        = string
  default     = "../api/lambda/function.zip"
}

variable "lab_role_arn" {
  description = "Learner Lab IAM role ARN"
  type        = string
}