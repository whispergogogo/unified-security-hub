# USH-3 · ECR Repositories — SAST + Pentest

resource "aws_ecr_repository" "sast" {
  name                 = "${var.project_prefix}-sast"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project     = "unified-security-hub"
    Environment = "dev"
  }
}

resource "aws_ecr_repository" "pentest" {
  name                 = "${var.project_prefix}-pentest"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project     = "unified-security-hub"
    Environment = "dev"
  }
}

# Intentionally vulnerable target API used for pentest integration testing
resource "aws_ecr_repository" "test_target" {
  name                 = "${var.project_prefix}-test-target"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project     = "unified-security-hub"
    Environment = "dev"
  }
}
