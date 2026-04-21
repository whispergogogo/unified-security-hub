# =============================================================================
# Lambda + API Gateway — Unified Security Hub API Layer
# =============================================================================

data "aws_caller_identity" "current" {}

# ── Lambda Function ───────────────────────────────────────────────────────
resource "aws_lambda_function" "api" {
  function_name    = "${var.project_name}-api"
  role             = var.lab_role_arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = var.lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda_zip_path)
  timeout          = 30

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
      S3_BUCKET      = var.s3_artifacts_name
      SFN_ARN        = var.sfn_arn
    }
  }

  # Explicitly bind Lambda to the Terraform-managed log group so AWS does not
  # auto-create a duplicate, and ensure the log group exists before the function.
  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.api.name
  }

  depends_on = [aws_cloudwatch_log_group.api]
}

resource "aws_cloudwatch_log_group" "api" {
  # Use var directly to avoid circular reference with aws_lambda_function.api
  name              = "/aws/lambda/${var.project_name}-api"
  retention_in_days = 14
}

# ── API Gateway ───────────────────────────────────────────────────────────
resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.project_name}-api"
  description = "Unified Security Hub REST API"
}

# ── Resources ─────────────────────────────────────────────────────────────
# /scan-jobs
resource "aws_api_gateway_resource" "scan_jobs" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "scan-jobs"
}

# /scan-jobs/{findingId}
resource "aws_api_gateway_resource" "scan_job" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.scan_jobs.id
  path_part   = "{findingId}"
}

# /scan-jobs/{findingId}/start
resource "aws_api_gateway_resource" "scan_job_start" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.scan_job.id
  path_part   = "start"
}

# /scan-jobs/{findingId}/report
resource "aws_api_gateway_resource" "scan_job_report" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.scan_job.id
  path_part   = "report"
}

# ── Lambda permission ─────────────────────────────────────────────────────
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# ── POST /scan-jobs ───────────────────────────────────────────────────────
resource "aws_api_gateway_method" "post_scan_jobs" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.scan_jobs.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}
resource "aws_api_gateway_integration" "post_scan_jobs" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.scan_jobs.id
  http_method             = aws_api_gateway_method.post_scan_jobs.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

# ── GET /scan-jobs ────────────────────────────────────────────────────────
resource "aws_api_gateway_method" "get_scan_jobs" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.scan_jobs.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = true
}
resource "aws_api_gateway_integration" "get_scan_jobs" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.scan_jobs.id
  http_method             = aws_api_gateway_method.get_scan_jobs.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

# ── OPTIONS /scan-jobs (CORS preflight) ───────────────────────────────────
resource "aws_api_gateway_method" "options_scan_jobs" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.scan_jobs.id
  http_method      = "OPTIONS"
  authorization    = "NONE"
  api_key_required = false
}
resource "aws_api_gateway_integration" "options_scan_jobs" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.scan_jobs.id
  http_method             = aws_api_gateway_method.options_scan_jobs.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

# ── GET /scan-jobs/{findingId} ────────────────────────────────────────────
resource "aws_api_gateway_method" "get_scan_job" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.scan_job.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = true
}
resource "aws_api_gateway_integration" "get_scan_job" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.scan_job.id
  http_method             = aws_api_gateway_method.get_scan_job.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

# ── OPTIONS /scan-jobs/{findingId} (CORS preflight) ───────────────────────
resource "aws_api_gateway_method" "options_scan_job" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.scan_job.id
  http_method      = "OPTIONS"
  authorization    = "NONE"
  api_key_required = false
}
resource "aws_api_gateway_integration" "options_scan_job" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.scan_job.id
  http_method             = aws_api_gateway_method.options_scan_job.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

# ── POST /scan-jobs/{findingId}/start ─────────────────────────────────────
resource "aws_api_gateway_method" "post_start" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.scan_job_start.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}
resource "aws_api_gateway_integration" "post_start" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.scan_job_start.id
  http_method             = aws_api_gateway_method.post_start.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

# ── OPTIONS /scan-jobs/{findingId}/start (CORS preflight) ─────────────────
resource "aws_api_gateway_method" "options_start" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.scan_job_start.id
  http_method      = "OPTIONS"
  authorization    = "NONE"
  api_key_required = false
}
resource "aws_api_gateway_integration" "options_start" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.scan_job_start.id
  http_method             = aws_api_gateway_method.options_start.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

# ── GET /scan-jobs/{findingId}/report ─────────────────────────────────────
resource "aws_api_gateway_method" "get_report" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.scan_job_report.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = true
}
resource "aws_api_gateway_integration" "get_report" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.scan_job_report.id
  http_method             = aws_api_gateway_method.get_report.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

# ── OPTIONS /scan-jobs/{findingId}/report (CORS preflight) ────────────────
resource "aws_api_gateway_method" "options_report" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.scan_job_report.id
  http_method      = "OPTIONS"
  authorization    = "NONE"
  api_key_required = false
}
resource "aws_api_gateway_integration" "options_report" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.scan_job_report.id
  http_method             = aws_api_gateway_method.options_report.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

# ── Deployment ────────────────────────────────────────────────────────────
resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  depends_on = [
    aws_api_gateway_integration.post_scan_jobs,
    aws_api_gateway_integration.get_scan_jobs,
    aws_api_gateway_integration.options_scan_jobs,
    aws_api_gateway_integration.get_scan_job,
    aws_api_gateway_integration.options_scan_job,
    aws_api_gateway_integration.post_start,
    aws_api_gateway_integration.options_start,
    aws_api_gateway_integration.get_report,
    aws_api_gateway_integration.options_report,
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.api.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "dev"
}

# ── API Key + Usage Plan ──────────────────────────────────────────────────
resource "aws_api_gateway_api_key" "main" {
  name    = "${var.project_name}-api-key"
  enabled = true
}

resource "aws_api_gateway_usage_plan" "main" {
  name = "${var.project_name}-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.api.id
    stage  = aws_api_gateway_stage.dev.stage_name
  }
}

resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.main.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.main.id
}