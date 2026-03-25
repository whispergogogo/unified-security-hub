output "table_name" {
  description = "Name of the DynamoDB security findings table"
  value       = aws_dynamodb_table.security_findings.name
}

output "table_arn" {
  description = "ARN of the DynamoDB security findings table"
  value       = aws_dynamodb_table.security_findings.arn
}

output "gsi_source_index" {
  description = "Name of the Source GSI"
  value       = "SourceIndex"
}

output "gsi_severity_index" {
  description = "Name of the Severity GSI"
  value       = "SeverityIndex"
}

output "gsi_status_index" {
  description = "Name of the Status GSI"
  value       = "StatusIndex"
}
