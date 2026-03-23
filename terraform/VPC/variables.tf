variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "unified-security-hub"
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet (NAT Gateway)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_a_cidr" {
  description = "CIDR block for private subnet A (SAST Fargate)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_b_cidr" {
  description = "CIDR block for private subnet B (Pentest Fargate)"
  type        = string
  default     = "10.0.3.0/24"
}

variable "availability_zones" {
  description = "List of AZs — [public + private-A, private-B]"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}
