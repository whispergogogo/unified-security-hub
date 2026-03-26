output "state_machine_arn" {
  value = aws_sfn_state_machine.scanner.arn
}

output "state_machine_name" {
  value = aws_sfn_state_machine.scanner.name
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
