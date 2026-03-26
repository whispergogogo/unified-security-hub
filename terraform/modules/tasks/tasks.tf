# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_prefix}-ecs-tasks-${var.environment}"
  description = "Security group for ECS Fargate tasks"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project     = "unified-security-hub"
    Environment = var.environment
  }
}

# SAST Task Definition
resource "aws_ecs_task_definition" "sast" {
  family                   = "${var.project_prefix}-sast"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.lab_role_arn
  task_role_arn            = var.lab_role_arn

  container_definitions = jsonencode([
    {
      name  = "sast"
      image = "${var.sast_repo_url}:latest"
      essential = true

      environment = [
        { name = "FINDING_ID",     value = "placeholder" },
        { name = "S3_BUCKET",      value = "placeholder" },
        { name = "DYNAMODB_TABLE", value = "placeholder" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.sast_log_group
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "sast"
        }
      }
    }
  ])
}

# Pentest Task Definition
resource "aws_ecs_task_definition" "pentest" {
  family                   = "${var.project_prefix}-pentest"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.lab_role_arn
  task_role_arn            = var.lab_role_arn

  container_definitions = jsonencode([
    {
      name  = "pentest"
      image = "${var.pentest_repo_url}:latest"
      essential = true

      environment = [
        { name = "FINDING_ID",     value = "placeholder" },
        { name = "TARGET_URL",     value = "placeholder" },
        { name = "S3_BUCKET",      value = "placeholder" },
        { name = "DYNAMODB_TABLE", value = "placeholder" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.pentest_log_group
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "pentest"
        }
      }
    }
  ])
}
