output "artifacts_bucket" {
  value = module.s3.artifacts_bucket_name
}

output "frontend_bucket" {
  value = module.s3.frontend_bucket_name
}

output "frontend_website_url" {
  value = module.s3.frontend_website_endpoint
}

output "dynamodb_table_name" {
  value = module.dynamodb.table_name
}

output "dynamodb_table_arn" {
  value = module.dynamodb.table_arn
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_id" {
  value = module.vpc.public_subnet_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "nat_gateway_id" {
  value = module.vpc.nat_gateway_id
}

output "cluster_arn" {
  value = module.ecs.cluster_arn
}

output "cluster_name" {
  value = module.ecs.cluster_name
}

output "sast_log_group" {
  value = module.ecs.sast_log_group_name
}

output "pentest_log_group" {
  value = module.ecs.pentest_log_group_name
}

output "sast_repo_url" {
  value = module.ecr.sast_repo_url
}

output "pentest_repo_url" {
  value = module.ecr.pentest_repo_url
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
