# Muestra por pantalla el nombre exacto del bucket S3 generado
output "s3_bucket_name" {
  description = "Nombre del bucket S3 creado para el laboratorio"
  value       = aws_s3_bucket.uploads_bucket.bucket
}

# Muestra por pantalla el nombre exacto de la función Lambda creada
output "lambda_function_name" {
  description = "Nombre de la función Lambda que procesa los eventos de S3"
  value       = aws_lambda_function.s3_processor.function_name
}
