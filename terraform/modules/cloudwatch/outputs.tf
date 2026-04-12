output "dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "failed_scans_alarm_arn" {
  description = "ARN of the failed scans alarm"
  value       = aws_cloudwatch_metric_alarm.failed_scans.arn
}
