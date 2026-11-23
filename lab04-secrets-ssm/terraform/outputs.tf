# Nombre del parámetro creado en SSM Parameter Store.
output "ssm_parameter_name" {
  description = "Nombre del parámetro SecureString en SSM Parameter Store"
  value       = aws_ssm_parameter.api_token.name
}

# Nombre de la función Lambda desplegada.
output "lambda_function_name" {
  description = "Nombre de la función Lambda que consume el parámetro"
  value       = aws_lambda_function.secret_consumer.function_name
}

# Log Group de CloudWatch donde revisar los orígenes de lectura (SSM vs caché).
output "log_group_name" {
  description = "Log Group de CloudWatch de la función Lambda"
  value       = aws_cloudwatch_log_group.secret_reader_logs.name
}