output "rds_password" {
  value = aws_secretsmanager_secret_version.secret_val[0].secret_string
  sensitive   = true
  description = "The password for logging in to the database."
}

output "secret_arn" {
  value = aws_secretsmanager_secret.secret[0].arn
  description = "secret ARN"
}

output "lambda_function_arn" {
  value = aws_lambda_function.redshift_secret.arn
  description = "lambda_function_arn"
}

 

 output "lambda_function_name" {
  value = aws_lambda_function.redshift_secret.function_name
  description = "lambda_function_name"
}