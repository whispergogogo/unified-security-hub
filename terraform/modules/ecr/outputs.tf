output "sast_repo_url" {
  value = aws_ecr_repository.sast.repository_url
}

output "pentest_repo_url" {
  value = aws_ecr_repository.pentest.repository_url
}

output "sast_repo_arn" {
  value = aws_ecr_repository.sast.arn
}

output "pentest_repo_arn" {
  value = aws_ecr_repository.pentest.arn
}
