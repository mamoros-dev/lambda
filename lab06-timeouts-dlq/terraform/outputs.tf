# Nombre de la función Lambda desplegada en el Lab 6.
output "lambda_function_name" {
  description = "Nombre de la función Lambda del Lab 6"
  value       = aws_lambda_function.resilient_worker.function_name
}

# URL de la cola SQS DLQ para consultar o purgar mensajes fallidos desde CLI.
output "dlq_queue_url" {
  description = "URL de la cola SQS Dead Letter Queue"
  value       = aws_sqs_queue.dlq.url
}

# ARN de la cola SQS DLQ.
output "dlq_queue_arn" {
  description = "ARN de la cola SQS Dead Letter Queue"
  value       = aws_sqs_queue.dlq.arn
}