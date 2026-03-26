variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "DynamoDB table ARN"
  type        = string
}

variable "s3_artifacts_name" {
  description = "Artifacts S3 bucket name"
  type        = string
}

variable "s3_artifacts_arn" {
  description = "Artifacts S3 bucket ARN"
  type        = string
}

variable "sfn_arn" {
  description = "Step Functions state machine ARN (placeholder until created)"
  type        = string
  default     = "placeholder"
}

variable "lambda_zip_path" {
  description = "Path to the Lambda zip file"
  type        = string
  default     = "../api/lambda/function.zip"
}

variable "lab_role_arn" {
  description = "Learner Lab IAM role ARN"
  type        = string
}