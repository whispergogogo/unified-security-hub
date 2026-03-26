output "api_url" {
  description = "API Gateway base URL"
  value       = "${aws_api_gateway_stage.dev.invoke_url}/scan-jobs"
}

output "api_key_id" {
  description = "API Key ID (get value from AWS Console or CLI)"
  value       = aws_api_gateway_api_key.main.id
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.api.function_name
}
