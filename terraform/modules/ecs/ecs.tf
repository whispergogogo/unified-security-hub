# USH-4 · ECS Cluster + CloudWatch Log Groups

resource "aws_ecs_cluster" "this" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Project     = "unified-security-hub"
    Environment = "dev"
  }
}

resource "aws_cloudwatch_log_group" "sast" {
  name              = "/ecs/${var.project_prefix}-sast"
  retention_in_days = var.log_retention_days

  tags = {
    Project     = "unified-security-hub"
    Environment = "dev"
  }
}

resource "aws_cloudwatch_log_group" "pentest" {
  name              = "/ecs/${var.project_prefix}-pentest"
  retention_in_days = var.log_retention_days

  tags = {
    Project     = "unified-security-hub"
    Environment = "dev"
  }
}
