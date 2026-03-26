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
