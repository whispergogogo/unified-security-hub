# ==============================================================
# Unified Security Hub — Root Terraform Configuration
# One "terraform apply" provisions ALL infrastructure.
# ==============================================================

module "vpc" {
  source = "./modules/vpc"

  project_name          = var.project_name
  environment           = var.environment
  aws_region            = var.aws_region
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidr    = var.public_subnet_cidr
  private_subnet_a_cidr = var.private_subnet_a_cidr
  private_subnet_b_cidr = var.private_subnet_b_cidr
  availability_zones    = var.availability_zones
}

module "dynamodb" {
  source = "./modules/dynamodb"

  project_name = var.project_name
  environment  = var.environment
}

module "ecr" {
  source = "./modules/ecr"

  project_prefix = var.project_prefix
}

module "ecs" {
  source = "./modules/ecs"

  cluster_name       = var.cluster_name
  project_prefix     = var.project_prefix
  log_retention_days = var.log_retention_days
}

module "s3" {
  source = "./modules/s3"

  artifacts_bucket_prefix = var.artifacts_bucket_prefix
  frontend_bucket_prefix  = var.frontend_bucket_prefix
  reports_expiry_days     = var.reports_expiry_days
}

module "sns" {
  source = "./modules/sns"

  project_name = var.project_name
  environment  = var.environment
  alert_email  = var.alert_email
}
