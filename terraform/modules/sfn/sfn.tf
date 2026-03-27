resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts-${var.environment}"
}

resource "aws_sfn_state_machine" "scanner" {
  name     = "${var.project_name}-scanner-${var.environment}"
  role_arn = var.lab_role_arn

  definition = jsonencode({
    Comment = "Unified Security Hub scan orchestration"
    StartAt = "UpdateStatusRunning"

    States = {
      UpdateStatusRunning = {
        Type    = "Task"
        Resource = "arn:aws:states:::dynamodb:updateItem"
        Parameters = {
          TableName = var.dynamodb_table_name
          Key = {
            finding_id = { "S.$" = "$.findingId" }
            timestamp  = { "S.$" = "$.timestamp" }
          }
          UpdateExpression = "SET #s = :s"
          ExpressionAttributeNames  = { "#s" = "status" }
          ExpressionAttributeValues = { ":s" = { S = "RUNNING" } }
        }
        ResultPath = null
        Next = "ChoiceScanType"
      }

      ChoiceScanType = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.scanType"
            StringEquals  = "SAST"
            Next          = "RunSASTTask"
          },
          {
            Variable      = "$.scanType"
            StringEquals  = "PENTEST"
            Next          = "RunPentestTask"
          }
        ]
        Default = "ScanFailed"
      }

      RunSASTTask = {
        Type     = "Task"
        Resource = "arn:aws:states:::ecs:runTask.sync"
        Parameters = {
          Cluster        = var.ecs_cluster_arn
          TaskDefinition = var.sast_task_definition_arn
          LaunchType     = "FARGATE"
          NetworkConfiguration = {
            AwsvpcConfiguration = {
              Subnets        = var.private_subnet_ids
              SecurityGroups = [var.ecs_security_group_id]
              AssignPublicIp = "DISABLED"
            }
          }
          Overrides = {
            ContainerOverrides = [
              {
                Name = "sast"
                Environment = [
                  { Name = "FINDING_ID", "Value.$" = "$.findingId" },
                  { Name = "S3_BUCKET",  Value = var.s3_artifacts_name },
                  { Name = "DYNAMODB_TABLE", Value = var.dynamodb_table_name }
                ]
              }
            ]
          }
        }
        # Store ECS output in $.taskResult — preserves original input fields
        ResultPath = "$.taskResult"
        Next  = "UpdateStatusCompleted"
        Catch = [{ ErrorEquals = ["States.ALL"], Next = "ScanFailed" }]
        Retry = [{ ErrorEquals = ["States.ALL"], MaxAttempts = 2, IntervalSeconds = 10 }]
      }

      RunPentestTask = {
        Type     = "Task"
        Resource = "arn:aws:states:::ecs:runTask.sync"
        Parameters = {
          Cluster        = var.ecs_cluster_arn
          TaskDefinition = var.pentest_task_definition_arn
          LaunchType     = "FARGATE"
          NetworkConfiguration = {
            AwsvpcConfiguration = {
              Subnets        = var.private_subnet_ids
              SecurityGroups = [var.ecs_security_group_id]
              AssignPublicIp = "DISABLED"
            }
          }
          Overrides = {
            ContainerOverrides = [
              {
                Name = "pentest"
                Environment = [
                  { Name = "FINDING_ID",  "Value.$" = "$.findingId" },
                  { Name = "TARGET_URL",  "Value.$" = "$.targetUrl" },
                  { Name = "S3_BUCKET",   Value = var.s3_artifacts_name },
                  { Name = "DYNAMODB_TABLE", Value = var.dynamodb_table_name }
                ]
              }
            ]
          }
        }
        # Store ECS output in $.taskResult — preserves original input fields
        ResultPath = "$.taskResult"
        Next  = "UpdateStatusCompleted"
        Catch = [{ ErrorEquals = ["States.ALL"], Next = "ScanFailed" }]
        Retry = [{ ErrorEquals = ["States.ALL"], MaxAttempts = 2, IntervalSeconds = 10 }]
      }

      UpdateStatusCompleted = {
        Type    = "Task"
        Resource = "arn:aws:states:::dynamodb:updateItem"
        Parameters = {
          TableName = var.dynamodb_table_name
          Key = {
            finding_id = { "S.$" = "$.findingId" }
            timestamp  = { "S.$" = "$.timestamp" }
          }
          UpdateExpression = "SET #s = :s"
          ExpressionAttributeNames  = { "#s" = "status" }
          ExpressionAttributeValues = { ":s" = { S = "COMPLETED" } }
        }
        ResultPath = null
        Next = "GetJobResult"
      }

      GetJobResult = {
        Type     = "Task"
        Resource = "arn:aws:states:::dynamodb:getItem"
        Parameters = {
          TableName = var.dynamodb_table_name
          Key = {
            finding_id = { "S.$" = "$.findingId" }
            timestamp  = { "S.$" = "$.timestamp" }
          }
        }
        ResultSelector = {
          "severity.$" = "$.Item.severity.S"
        }
        ResultPath = "$.jobResult"
        Next = "CheckSeverity"
      }

      CheckSeverity = {
        Type = "Choice"
        Choices = [
          {
            Variable     = "$.jobResult.severity"
            StringEquals = "CRITICAL"
            Next         = "SendAlert"
          },
          {
            Variable     = "$.jobResult.severity"
            StringEquals = "HIGH"
            Next         = "SendAlert"
          }
        ]
        Default = "ScanSucceeded"
      }

      SendAlert = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = aws_sns_topic.alerts.arn
          Message = {
            "Input.$" = "States.Format('High severity finding detected. ID: {}, Severity: {}', $.findingId, $.jobResult.severity)"
          }
        }
        Next = "ScanSucceeded"
      }

      ScanSucceeded = {
        Type = "Succeed"
      }

      ScanFailed = {
        Type    = "Task"
        Resource = "arn:aws:states:::dynamodb:updateItem"
        Parameters = {
          TableName = var.dynamodb_table_name
          Key = {
            finding_id = { "S.$" = "$.findingId" }
            timestamp  = { "S.$" = "$.timestamp" }
          }
          UpdateExpression = "SET #s = :s"
          ExpressionAttributeNames  = { "#s" = "status" }
          ExpressionAttributeValues = { ":s" = { S = "FAILED" } }
        }
        Next = "ScanError"
      }

      ScanError = {
        Type  = "Fail"
        Error = "ScanFailed"
        Cause = "ECS task failed"
      }
    }
  })
}
