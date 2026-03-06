# =============================================================================
# DynamoDB Table + GSIs for Unified Security Hub
# =============================================================================
# Table Design:
#   PK: finding_id (S)  — unique ID for each security finding
#   SK: timestamp  (S)  — ISO-8601 timestamp for time-range queries
#
# Access Patterns Served:
#   1. Get finding by ID + timestamp        → Base table
#   2. List findings by source + time range → GSI: SourceIndex
#   3. List findings by severity + time      → GSI: SeverityIndex
#   4. List findings by status + time        → GSI: StatusIndex
# =============================================================================

resource "aws_dynamodb_table" "security_findings" {
  name         = "${var.project_name}-findings-${var.environment}"
  billing_mode = "PAY_PER_REQUEST" # Best for Learner Lab (no capacity planning)
  hash_key     = "finding_id"
  range_key    = "timestamp"

  # --- Key attributes (only those used as keys need to be declared here) ----
  attribute {
    name = "finding_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "source"
    type = "S"
  }

  attribute {
    name = "severity"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  # --- GSI 1: Query findings by source (e.g., guardduty, inspector, macie) --
  global_secondary_index {
    name            = "SourceIndex"
    hash_key        = "source"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  # --- GSI 2: Query findings by severity (CRITICAL, HIGH, MEDIUM, LOW, INFO) -
  global_secondary_index {
    name            = "SeverityIndex"
    hash_key        = "severity"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  # --- GSI 3: Query findings by status (OPEN, IN_PROGRESS, RESOLVED, CLOSED) -
  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  # --- Point-in-time recovery (good practice, free-tier eligible) -----------
  point_in_time_recovery {
    enabled = true
  }

  # --- Tags -----------------------------------------------------------------
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Ticket      = "USH-1"
  }
}
