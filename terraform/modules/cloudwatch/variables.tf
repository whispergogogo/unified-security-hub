variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications"
  type        = string
}

variable "state_machine_arn" {
  description = "Step Functions state machine ARN"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS Fargate cluster name"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name"
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda function name"
  type        = string
}

variable "sast_log_group" {
  description = "CloudWatch log group for SAST tasks"
  type        = string
}

variable "pentest_log_group" {
  description = "CloudWatch log group for Pentest tasks"
  type        = string
}
