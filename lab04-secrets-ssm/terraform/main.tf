# ==========================================
# 1. SECRETO EN SSM PARAMETER STORE
# ==========================================

# Crea un parámetro cifrado (SecureString) en SSM Parameter Store.
# En entornos reales es habitual crear/rotar el valor fuera de Terraform o inyectarlo
# por variable de entorno/CI/CD sin dejar valores sensibles fijos en el repositorio.
resource "aws_ssm_parameter" "api_token" {
  name        = "/lab4/demo/api-token"
  description = "Token de ejemplo cifrado para el Lab 4 de Lambda"
  type        = "SecureString"
  value       = var.demo_api_token

  tags = {
    Laboratorio = "Lab4-SSM-Secrets"
  }
}

# ==========================================
# 2. EMPAQUETADO Y LOGS (CLOUDWATCH)
# ==========================================

# Comprime secret_reader.py en secret_reader.zip para desplegarlo en Lambda.
data "archive_file" "secret_reader_zip" {
  type        = "zip"
  source_file = "${path.module}/secret_reader.py"
  output_path = "${path.module}/secret_reader.zip"
}

# Crea el Log Group antes de ejecutar la función y fija retención a 7 días.
resource "aws_cloudwatch_log_group" "secret_reader_logs" {
  name              = "/aws/lambda/lab4-secret-consumer"
  retention_in_days = 1 #7

  tags = {
    Laboratorio = "Lab4-SSM-Secrets"
  }
}

# ==========================================
# 3. ROL IAM DE MÍNIMO PRIVILEGIO
# ==========================================

# Trust Policy: permite que el servicio AWS Lambda asuma este rol.
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Rol de ejecución de la función Lambda.
resource "aws_iam_role" "lambda_exec_role" {
  name               = "lab4-secret-consumer-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Política 1: permiso para escribir logs en CloudWatch.
data "aws_iam_policy_document" "lambda_logs_doc" {
  statement {
    sid    = "CloudWatchLogsWrite"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "lambda_logs_policy" {
  name        = "lab4-secret-consumer-logs-policy"
  description = "Permite escribir logs de ejecución del Lab 4 en CloudWatch"
  policy      = data.aws_iam_policy_document.lambda_logs_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_logs_policy.arn
}

# Política 2: mínimo privilegio para leer ÚNICAMENTE el parámetro /lab4/demo/api-token.
# (Si el parámetro usa la clave KMS por defecto de SSM, aws:GetParameter con WithDecryption
# funciona a través de SSM; si usas una CMK propia, también se añade kms:Decrypt sobre esa clave).
data "aws_iam_policy_document" "lambda_ssm_read_doc" {
  statement {
    sid       = "ReadLab4ParameterOnly"
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.api_token.arn]
  }
}

resource "aws_iam_policy" "lambda_ssm_read_policy" {
  name        = "lab4-secret-consumer-ssm-policy"
  description = "Permite leer únicamente el parámetro /lab4/demo/api-token en SSM"
  policy      = data.aws_iam_policy_document.lambda_ssm_read_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_ssm_read_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_ssm_read_policy.arn
}

# ==========================================
# 4. FUNCIÓN LAMBDA
# ==========================================

# Crea la función Lambda que leerá el parámetro en ejecución y lo cacheará en memoria.
resource "aws_lambda_function" "secret_consumer" {
  filename         = data.archive_file.secret_reader_zip.output_path
  function_name    = "lab4-secret-consumer"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "secret_reader.lambda_handler"
  source_code_hash = data.archive_file.secret_reader_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 10

  # Pasamos solo el nombre/ruta del parámetro (no el secreto en claro).
  environment {
    variables = {
      PARAMETER_NAME = aws_ssm_parameter.api_token.name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs_attach,
    aws_iam_role_policy_attachment.lambda_ssm_read_attach,
    aws_cloudwatch_log_group.secret_reader_logs
  ]
}