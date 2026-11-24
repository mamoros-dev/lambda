# Outputs for the VPC Lambda Terraform module
output "lambda_function_name" {
  value = aws_lambda_function.vpc_checker.function_name
}

# Output for the CloudWatch Log Group associated with the Lambda function
output "log_group_name" {
  value = aws_cloudwatch_log_group.vpc_checker_logs.name
}

# Output for VPC ID
output "vpc_id" {
  value = aws_vpc.lab_vpc.id
}

# Output for s3 gateway endpoint ID
output "s3_gateway_endpoint_id" {
  value = aws_vpc_endpoint.s3_endpoint.id
}