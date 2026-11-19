# Nombre de la tabla DynamoDB creada para el laboratorio
output "dynamodb_table_name" {
  description = "Nombre de la tabla DynamoDB utilizada por la Lambda"
  value       = aws_dynamodb_table.eventos_table.name
}

# Nombre de la función Lambda desplegada
output "lambda_function_name" {
  description = "Nombre de la función Lambda que gestiona los registros en DynamoDB"
  value       = aws_lambda_function.dynamodb_handler.function_name
}