output "cluster_id" {
  value = aws_ecs_cluster.this.id
}

output "cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "sast_log_group_name" {
  value = aws_cloudwatch_log_group.sast.name
}

output "pentest_log_group_name" {
  value = aws_cloudwatch_log_group.pentest.name
}

output "test_target_log_group_name" {
  value = aws_cloudwatch_log_group.test_target.name
}