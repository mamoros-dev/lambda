# ==========================================
# 1. EMPAQUETADO Y LOGS (CLOUDWATCH)
# ==========================================

# Comprime http_api.py en http_api.zip para subirlo a AWS Lambda.
data "archive_file" "http_api_zip" {
  type        = "zip"
  source_file = "${path.module}/http_api.py"
  output_path = "${path.module}/http_api.zip"
}

# Crea el Log Group con retención de 7 días para auditar las peticiones HTTP recibidas.
resource "aws_cloudwatch_log_group" "http_api_logs" {
  name              = "/aws/lambda/lab5-http-api"
  retention_in_days = 1 #7

  tags = {
    Laboratorio = "Lab5-HTTP-Function-URL"
  }
}

# ==========================================
# 2. ROL IAM DE EJECUCIÓN DE LA LAMBDA
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

# Rol IAM asignado a la función Lambda.
resource "aws_iam_role" "lambda_exec_role" {
  name               = "lab5-http-api-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Permisos mínimos para que la Lambda escriba sus logs en CloudWatch.
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
  name        = "lab5-http-api-logs-policy"
  description = "Permite a la Lambda del Lab 5 escribir logs en CloudWatch"
  policy      = data.aws_iam_policy_document.lambda_logs_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_logs_policy.arn
}

# ==========================================
# 3. FUNCIÓN LAMBDA
# ==========================================

# Crea la función Lambda que actuará como backend de nuestro endpoint HTTP.
resource "aws_lambda_function" "http_api" {
  filename         = data.archive_file.http_api_zip.output_path
  function_name    = "lab5-http-api"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "http_api.lambda_handler"
  source_code_hash = data.archive_file.http_api_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 10

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs_attach,
    aws_cloudwatch_log_group.http_api_logs
  ]
}

# ==========================================
# 4. LAMBDA FUNCTION URL (ENDPOINT HTTPS)
# ==========================================

# Expone la función Lambda mediante una URL HTTPS dedicada.
# authorization_type = "NONE" permite llamarla públicamente (como un webhook o API abierta);
# en entornos internos donde solo llaman servicios AWS se usa "AWS_IAM".
resource "aws_lambda_function_url" "public_endpoint" {
  function_name      = aws_lambda_function.http_api.function_name
  authorization_type = "NONE"

  # Configuración CORS básica para permitir llamadas desde navegadores o frontends.
  cors {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST"]
    allow_headers = ["content-type"]
  }
}

# ==========================================
# 5. PERMISO DE INVOCACIÓN PÚBLICA A LA FUNCTION URL
# ==========================================

# Sin este permiso en la política de recursos de la Lambda, AWS bloquea las llamadas
# a la Function URL con 403 Forbidden incluso cuando authorization_type = "NONE".
resource "aws_lambda_permission" "allow_public_function_url" {
  statement_id           = "AllowPublicFunctionUrlInvoke"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.http_api.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}
