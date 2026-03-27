# USH-4 · S3 Buckets — Artifacts + Frontend

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

# --- Artifacts Bucket ---

resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.artifacts_bucket_prefix}-${local.account_id}"
  force_destroy = true  # Allow destroy even when bucket contains objects

  tags = {
    Project     = "unified-security-hub"
    Environment = "dev"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-reports-90-days"
    status = "Enabled"

    filter {
      prefix = "reports/"
    }

    expiration {
      days = var.reports_expiry_days
    }
  }
}

# --- Frontend Bucket ---

resource "aws_s3_bucket" "frontend" {
  bucket = "${var.frontend_bucket_prefix}-${local.account_id}"
  force_destroy = true  # Allow destroy even when bucket contains objects

  tags = {
    Project     = "unified-security-hub"
    Environment = "dev"
  }
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}
