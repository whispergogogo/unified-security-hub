output "sast_task_definition_arn" {
  value = aws_ecs_task_definition.sast.arn
}

output "pentest_task_definition_arn" {
  value = aws_ecs_task_definition.pentest.arn
}

output "ecs_security_group_id" {
  value = aws_security_group.ecs_tasks.id
}

output "test_target_task_definition_arn" {
  value = aws_ecs_task_definition.test_target.arn
}

output "test_target_security_group_id" {
  value = aws_security_group.test_target.id
}