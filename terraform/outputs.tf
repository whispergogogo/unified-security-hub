# ==============================================================
# VPC Outputs
# ==============================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = module.vpc.public_subnet_id
}

output "private_subnet_ids" {
  description = "List of all private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = module.vpc.nat_gateway_id
}

# ==============================================================
# DynamoDB Outputs
# ==============================================================

output "dynamodb_table_name" {
  description = "Name of the DynamoDB findings table"
  value       = module.dynamodb.table_name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB findings table"
  value       = module.dynamodb.table_arn
}

# ==============================================================
# ECR Outputs
# ==============================================================

output "sast_repo_url" {
  description = "SAST ECR repository URL"
  value       = module.ecr.sast_repo_url
}

output "pentest_repo_url" {
  description = "Pentest ECR repository URL"
  value       = module.ecr.pentest_repo_url
}

# ==============================================================
# ECS Outputs
# ==============================================================

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = module.ecs.cluster_arn
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "sast_log_group" {
  description = "SAST CloudWatch log group name"
  value       = module.ecs.sast_log_group_name
}

output "pentest_log_group" {
  description = "Pentest CloudWatch log group name"
  value       = module.ecs.pentest_log_group_name
}

# ==============================================================
# S3 Outputs
# ==============================================================

output "artifacts_bucket" {
  description = "Artifacts S3 bucket name"
  value       = module.s3.artifacts_bucket_name
}

output "frontend_bucket" {
  description = "Frontend S3 bucket name"
  value       = module.s3.frontend_bucket_name
}

output "frontend_website_url" {
  description = "Frontend website endpoint"
  value       = module.s3.frontend_website_endpoint
}

output "api_url" {
  value = module.lambda.api_url
}

output "api_key_id" {
  value = module.lambda.api_key_id
}

output "lambda_function_name" {
  value = module.lambda.lambda_function_name
}
output "api_url" {
  value = module.lambda.api_url
}

output "api_key_id" {
  value = module.lambda.api_key_id
}

output "lambda_function_name" {
  value = module.lambda.lambda_function_name
}
