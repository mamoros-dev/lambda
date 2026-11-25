output "lambda_function_name" {
  description = "Nombre de la función Lambda del Lab 8"
  value       = aws_lambda_function.layers_demo.function_name
}

output "layer_version_arn" {
  description = "ARN completo de la versión publicada de la Lambda Layer"
  value       = aws_lambda_layer_version.shared_layer.arn
}

output "layer_version_number" {
  description = "Número de versión de la Lambda Layer"
  value       = aws_lambda_layer_version.shared_layer.version
}