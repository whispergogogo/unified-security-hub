project_name = "unified-security-hub"
environment  = "dev"
aws_region   = "us-east-1"

vpc_cidr              = "10.0.0.0/16"
public_subnet_cidr    = "10.0.1.0/24"
private_subnet_a_cidr = "10.0.2.0/24"
private_subnet_b_cidr = "10.0.3.0/24"
availability_zones    = ["us-east-1a", "us-east-1b"]
