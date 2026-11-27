# outputs.tf

output "documents_bucket_name" {
  description = "Nombre del bucket S3 donde subir documentos de prueba"
  value       = aws_s3_bucket.documents_bucket.bucket
}

output "audit_table_name" {
  description = "Nombre de la tabla DynamoDB de auditoría"
  value       = aws_dynamodb_table.audit_table.name
}

output "audit_dlq_url" {
  description = "URL de la cola SQS DLQ para inspeccionar eventos fallidos"
  value       = aws_sqs_queue.audit_dlq.url
}

output "lambda_function_name" {
  description = "Nombre de la función Lambda del Lab 09"
  value       = aws_lambda_function.document_audit.function_name
}

output "log_group_name" {
  description = "Grupo de logs de CloudWatch de la función Lambda"
  value       = aws_cloudwatch_log_group.audit_lambda_logs.name
}