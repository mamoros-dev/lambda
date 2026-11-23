# Outputs for the scheduled Lambda function
output "lambda_function_name" {
  description = "Nombre de la función Lambda ejecutada por la programación"
  value       = aws_lambda_function.scheduler_worker.function_name
}
# Outputs for the EventBridge Scheduler
output "scheduler_name" {
  description = "Nombre del programador de EventBridge Scheduler"
  value       = aws_scheduler_schedule.every_5_minutes.name
}
# Outputs for the CloudWatch Log Group
output "log_group_name" {
  description = "Log Group de CloudWatch donde se registran las ejecuciones"
  value       = aws_cloudwatch_log_group.scheduler_worker_logs.name
}