# Security Group for ECS Tasks (SAST + Pentest scanners — outbound only)
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

# Security Group for test-target — allows inbound on port 4000 from anywhere
resource "aws_security_group" "test_target" {
  name        = "${var.project_prefix}-test-target-${var.environment}"
  description = "Security group for the vulnerable test target API"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 4000
    to_port     = 4000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow inbound HTTP traffic for pentest testing"
  }

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

# Test Target Task Definition — long-running server deployed in public subnet
resource "aws_ecs_task_definition" "test_target" {
  family                   = "${var.project_prefix}-test-target"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.lab_role_arn
  task_role_arn            = var.lab_role_arn

  container_definitions = jsonencode([
    {
      name      = "test-target"
      image     = "${var.test_target_repo_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 4000
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.test_target_log_group
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "test-target"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "test_target" {
  name            = "${var.project_prefix}-test-target"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.test_target.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [var.public_subnet_id]
    security_groups  = [aws_security_group.test_target.id]
    assign_public_ip = true
  }
}
