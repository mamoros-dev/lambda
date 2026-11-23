# Muestra la URL HTTPS generada por AWS para invocar nuestra función directamente con curl o navegador.
output "function_url" {
  description = "Endpoint HTTPS público de la función Lambda"
  value       = aws_lambda_function_url.public_endpoint.function_url
}

# Nombre de la función Lambda desplegada.
output "lambda_function_name" {
  description = "Nombre de la función Lambda del Lab 5"
  value       = aws_lambda_function.http_api.function_name
}