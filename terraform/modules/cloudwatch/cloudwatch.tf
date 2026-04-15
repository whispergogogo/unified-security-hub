# =============================================================================
# USH-26 · CloudWatch Dashboard + Alarms
# =============================================================================

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [

      # ── Row 1: Step Functions ────────────────────────────────────────────
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Step Functions — Executions"
          region  = var.aws_region
          metrics = [
            ["AWS/States", "ExecutionsStarted",   "StateMachineArn", var.state_machine_arn, { stat = "Sum", label = "Started" }],
            ["AWS/States", "ExecutionsSucceeded",  "StateMachineArn", var.state_machine_arn, { stat = "Sum", label = "Succeeded" }],
            ["AWS/States", "ExecutionsFailed",     "StateMachineArn", var.state_machine_arn, { stat = "Sum", label = "Failed" }],
            ["AWS/States", "ExecutionsTimedOut",    "StateMachineArn", var.state_machine_arn, { stat = "Sum", label = "Timed Out" }]
          ]
          period = 300
          view   = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Step Functions — Execution Duration"
          region  = var.aws_region
          metrics = [
            ["AWS/States", "ExecutionTime", "StateMachineArn", var.state_machine_arn, { stat = "Average", label = "Avg (ms)" }],
            ["AWS/States", "ExecutionTime", "StateMachineArn", var.state_machine_arn, { stat = "p99",     label = "p99 (ms)" }]
          ]
          period = 300
          view   = "timeSeries"
        }
      },

      # ── Row 2: ECS Fargate ──────────────────────────────────────────────
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "ECS Fargate — Task Counts"
          region  = var.aws_region
          metrics = [
            ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.ecs_cluster_name, { stat = "Average", label = "Running" }],
            ["ECS/ContainerInsights", "PendingTaskCount", "ClusterName", var.ecs_cluster_name, { stat = "Average", label = "Pending" }]
          ]
          period = 300
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "ECS Fargate — CPU & Memory"
          region  = var.aws_region
          metrics = [
            ["ECS/ContainerInsights", "CpuUtilized",    "ClusterName", var.ecs_cluster_name, { stat = "Average", label = "CPU Utilized" }],
            ["ECS/ContainerInsights", "MemoryUtilized",  "ClusterName", var.ecs_cluster_name, { stat = "Average", label = "Memory Utilized" }]
          ]
          period = 300
          view   = "timeSeries"
        }
      },

      # ── Row 3: Lambda ───────────────────────────────────────────────────
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title   = "Lambda — Invocations & Errors"
          region  = var.aws_region
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_function_name, { stat = "Sum", label = "Invocations" }],
            ["AWS/Lambda", "Errors",      "FunctionName", var.lambda_function_name, { stat = "Sum", label = "Errors" }],
            ["AWS/Lambda", "Throttles",   "FunctionName", var.lambda_function_name, { stat = "Sum", label = "Throttles" }]
          ]
          period = 300
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title   = "Lambda — Duration"
          region  = var.aws_region
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_name, { stat = "Average", label = "Avg (ms)" }],
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_name, { stat = "p99",     label = "p99 (ms)" }]
          ]
          period = 300
          view   = "timeSeries"
        }
      },

      # ── Row 4: DynamoDB ─────────────────────────────────────────────────
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          title   = "DynamoDB — Consumed Capacity"
          region  = var.aws_region
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits",  "TableName", var.dynamodb_table_name, { stat = "Sum", label = "Read" }],
            ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", "TableName", var.dynamodb_table_name, { stat = "Sum", label = "Write" }]
          ]
          period = 300
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6
        properties = {
          title   = "DynamoDB — Errors & Throttles"
          region  = var.aws_region
          metrics = [
            ["AWS/DynamoDB", "ThrottledRequests",    "TableName", var.dynamodb_table_name, { stat = "Sum", label = "Throttled" }],
            ["AWS/DynamoDB", "SystemErrors",          "TableName", var.dynamodb_table_name, { stat = "Sum", label = "System Errors" }],
            ["AWS/DynamoDB", "UserErrors",             "TableName", var.dynamodb_table_name, { stat = "Sum", label = "User Errors" }]
          ]
          period = 300
          view   = "timeSeries"
        }
      },

      # ── Row 5: Recent errors in scanner logs ────────────────────────────
      {
        type   = "log"
        x      = 0
        y      = 24
        width  = 12
        height = 6
        properties = {
          title  = "SAST Scanner — Recent Errors"
          region = var.aws_region
          query  = "SOURCE '${var.sast_log_group}' | filter @message like /(?i)(error|exception|fatal|fail)/ | sort @timestamp desc | limit 20"
          view   = "table"
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 24
        width  = 12
        height = 6
        properties = {
          title  = "Pentest Scanner — Recent Errors"
          region = var.aws_region
          query  = "SOURCE '${var.pentest_log_group}' | filter @message like /(?i)(error|exception|fatal|fail)/ | sort @timestamp desc | limit 20"
          view   = "table"
        }
      }
    ]
  })
}

# =============================================================================
# Alarm: 3+ failed scans in 1 hour → SNS
# =============================================================================
resource "aws_cloudwatch_metric_alarm" "failed_scans" {
  alarm_name          = "${var.project_name}-${var.environment}-failed-scans"
  alarm_description   = "3 or more Step Functions executions failed within 1 hour"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 3
  treat_missing_data  = "notBreaching"

  metric_name = "ExecutionsFailed"
  namespace   = "AWS/States"
  statistic   = "Sum"
  period      = 3600 # 1 hour

  dimensions = {
    StateMachineArn = var.state_machine_arn
  }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
