# compute.tf

# Empaqueta el código de la función Lambda (sin duplicar la Layer).
data "archive_file" "audit_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/audit_handler.py"
  output_path = "${path.module}/audit_handler.zip"
}

# Log Group explícito con retención de 7 días para evitar acumulación indefinida de logs.
resource "aws_cloudwatch_log_group" "audit_lambda_logs" {
  name              = "/aws/lambda/lab09-document-audit"
  retention_in_days = 1 #7
}

# Política de confianza: solo el servicio AWS Lambda puede asumir este rol.
data "aws_iam_policy_document" "audit_lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "audit_lambda_role" {
  name               = "lab09-document-audit-role"
  assume_role_policy = data.aws_iam_policy_document.audit_lambda_assume_role.json
}

# Política de mínimo privilegio acotada a los recursos exactos del Lab 09.
data "aws_iam_policy_document" "audit_lambda_least_privilege_doc" {
  # 1. Escritura de logs únicamente en el grupo de logs de esta Lambda
  statement {
    sid    = "CloudWatchLogsScoped"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      aws_cloudwatch_log_group.audit_lambda_logs.arn,
      "${aws_cloudwatch_log_group.audit_lambda_logs.arn}:*"
    ]
  }

  # 2. Gestión de ENIs en VPC para ejecutar la Lambda dentro de las subredes privadas
  statement {
    sid    = "LambdaVPCAccess"
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:AssignPrivateIpAddresses",
      "ec2:UnassignPrivateIpAddresses"
    ]
    resources = ["*"]
  }

  # 3. Leer objetos únicamente del bucket de documentos del Lab 09
  statement {
    sid       = "ReadLab09DocumentsBucket"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.documents_bucket.arn}/*"]
  }

  # 4. Insertar registros únicamente en la tabla DynamoDB de auditoría del Lab 09
  statement {
    sid       = "WriteLab09AuditTable"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.audit_table.arn]
  }

  # 5. Enviar mensajes de fallo únicamente a la cola SQS DLQ del Lab 09
  statement {
    sid       = "SendToLab09Dlq"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.audit_dlq.arn]
  }
}

resource "aws_iam_policy" "audit_lambda_least_privilege" {
  name        = "lab09-document-audit-least-privilege"
  description = "Minimo privilegio para auditar documentos de S3 en DynamoDB desde VPC"
  policy      = data.aws_iam_policy_document.audit_lambda_least_privilege_doc.json
}

resource "aws_iam_role_policy_attachment" "audit_lambda_attach" {
  role       = aws_iam_role.audit_lambda_role.name
  policy_arn = aws_iam_policy.audit_lambda_least_privilege.arn
}

# Función Lambda principal conectada a la VPC privada y a la Layer de utilidades.
resource "aws_lambda_function" "document_audit" {
  filename         = data.archive_file.audit_lambda_zip.output_path
  function_name    = "lab09-document-audit"
  role             = aws_iam_role.audit_lambda_role.arn
  handler          = "audit_handler.lambda_handler"
  source_code_hash = data.archive_file.audit_lambda_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 15
  memory_size      = 128

  # Conecta la Lambda a las dos subredes privadas y al Security Group (Lab 7)
  vpc_config {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  # Adjunta la versión de Lambda Layer con audit_utils.py (Lab 8)
  layers = [aws_lambda_layer_version.audit_layer.arn]

  # Variables de entorno para no hardcodear nombres de recursos en Python
  environment {
    variables = {
      AUDIT_TABLE_NAME = aws_dynamodb_table.audit_table.name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.audit_lambda_attach,
    aws_cloudwatch_log_group.audit_lambda_logs,
    aws_vpc_endpoint.s3_gateway
  ]
}

# Configura reintentos automáticos y envío a SQS DLQ cuando falla una invocación asíncrona (Lab 6)
resource "aws_lambda_function_event_invoke_config" "audit_async_config" {
  function_name                = aws_lambda_function.document_audit.function_name
  maximum_retry_attempts       = 2
  maximum_event_age_in_seconds = 300

  destination_config {
    on_failure {
      destination = aws_sqs_queue.audit_dlq.arn
    }
  }
}