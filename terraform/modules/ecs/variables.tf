variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "project_prefix" {
  description = "Prefix for log group names"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days"
  type        = number
}
