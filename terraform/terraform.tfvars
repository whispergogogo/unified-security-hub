aws_region   = "us-east-1"
project_name = "unified-security-hub"
environment  = "dev"

# ==============================================================
# VPC
# ==============================================================
vpc_cidr              = "10.0.0.0/16"
public_subnet_cidr    = "10.0.1.0/24"
private_subnet_a_cidr = "10.0.2.0/24"
private_subnet_b_cidr = "10.0.3.0/24"
availability_zones    = ["us-east-1a", "us-east-1b"]

# ==============================================================
# ECS + ECR
# ==============================================================
cluster_name       = "unified-security-hub"
project_prefix     = "security-hub-dev"
log_retention_days = 14

# ==============================================================
# S3
# ==============================================================
artifacts_bucket_prefix = "ush-artifacts"
frontend_bucket_prefix  = "ush-frontend"
reports_expiry_days     = 90

# ==============================================================
# SNS
# ==============================================================
alert_email = "kaushik.aar@northeastern.edu"