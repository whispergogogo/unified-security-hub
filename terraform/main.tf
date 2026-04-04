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

module "lambda" {
  source = "./modules/lambda"

  project_name        = var.project_name
  dynamodb_table_name = module.dynamodb.table_name
  dynamodb_table_arn  = module.dynamodb.table_arn
  s3_artifacts_name   = module.s3.artifacts_bucket_name
  s3_artifacts_arn    = module.s3.artifacts_bucket_arn
  sfn_arn             = module.sfn.state_machine_arn
  lambda_zip_path     = var.lambda_zip_path
  lab_role_arn = var.lab_role_arn
}

module "tasks" {
  source = "./modules/tasks"

  project_prefix    = var.project_prefix
  environment       = var.environment
  lab_role_arn      = var.lab_role_arn
  sast_repo_url     = module.ecr.sast_repo_url
  pentest_repo_url  = module.ecr.pentest_repo_url
  sast_log_group    = module.ecs.sast_log_group_name
  pentest_log_group = module.ecs.pentest_log_group_name
  vpc_id            = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  # Test target additions
  test_target_repo_url  = module.ecr.test_target_repo_url
  test_target_log_group = module.ecs.test_target_log_group_name
  public_subnet_id      = module.vpc.public_subnet_id
  ecs_cluster_id        = module.ecs.cluster_id
}

module "sfn" {
  source = "./modules/sfn"

  project_name                = var.project_name
  environment                 = var.environment
  lab_role_arn                = var.lab_role_arn
  dynamodb_table_arn          = module.dynamodb.table_arn
  dynamodb_table_name         = module.dynamodb.table_name
  s3_artifacts_arn            = module.s3.artifacts_bucket_arn
  s3_artifacts_name           = module.s3.artifacts_bucket_name
  ecs_cluster_arn             = module.ecs.cluster_arn
  sast_task_definition_arn    = module.tasks.sast_task_definition_arn
  pentest_task_definition_arn = module.tasks.pentest_task_definition_arn
  private_subnet_ids          = module.vpc.private_subnet_ids
  ecs_security_group_id       = module.tasks.ecs_security_group_id
}
