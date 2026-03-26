variable "project_name" {
  type = string
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "dynamodb_table_arn" {
  type = string
}

variable "s3_artifacts_arn" {
  type = string
}

variable "lab_role_arn" {
  type = string
}

variable "ecs_cluster_arn" {
  type = string
}

variable "sast_task_definition_arn" {
  type = string
}

variable "pentest_task_definition_arn" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "ecs_security_group_id" {
  type = string
}

variable "dynamodb_table_name" {
  type = string
}

variable "s3_artifacts_name" {
  type = string
}
