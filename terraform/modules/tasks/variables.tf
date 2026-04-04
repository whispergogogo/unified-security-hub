variable "project_prefix" {
  type = string
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "lab_role_arn" {
  type = string
}

variable "sast_repo_url" {
  type = string
}

variable "pentest_repo_url" {
  type = string
}

variable "sast_log_group" {
  type = string
}

variable "pentest_log_group" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "test_target_repo_url" {
  description = "ECR repository URL for the vulnerable test target image"
  type        = string
}

variable "test_target_log_group" {
  description = "CloudWatch log group name for the test target container"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID — test-target runs here with a public IP"
  type        = string
}

variable "ecs_cluster_id" {
  description = "ECS cluster ID for running the test-target service"
  type        = string
}