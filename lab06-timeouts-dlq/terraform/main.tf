# ==========================================
# 1. DEAD LETTER QUEUE (COLA SQS)
# ==========================================

# Cola SQS donde aterrizarán los eventos asíncronos que fallen tras agotar los reintentos.
# message_retention_seconds = 86400 conserva los mensajes fallidos 24 horas para analizarlos.
resource "aws_sqs_queue" "dlq" {
  name                      = "lab6-events-dlq"
  message_retention_seconds = 86400

  tags = {
    Laboratorio = "Lab6-Timeouts-Retries-DLQ"
  }
}

# ==========================================
# 2. EMPAQUETADO Y LOGS (CLOUDWATCH)
# ==========================================

# Empaqueta resilient_worker.py en un archivo .zip para desplegarlo en Lambda.
data "archive_file" "resilient_worker_zip" {
  type        = "zip"
  source_file = "${path.module}/resilient_worker.py"
  output_path = "${path.module}/resilient_worker.zip"
}

# Crea el Log Group con retención de 7 días para inspeccionar reintentos y timeouts.
resource "aws_cloudwatch_log_group" "resilient_worker_logs" {
  name              = "/aws/lambda/lab6-resilient-worker"
  retention_in_days = 1 #7

  tags = {
    Laboratorio = "Lab6-Timeouts-Retries-DLQ"
  }
}

# ==========================================
# 3. ROL IAM DE EJECUCIÓN DE LA LAMBDA
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

# Rol IAM que usará la función Lambda.
resource "aws_iam_role" "lambda_exec_role" {
  name               = "lab6-resilient-worker-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Permisos para escribir logs en CloudWatch.
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
  name        = "lab6-resilient-worker-logs-policy"
  description = "Permite escribir logs de ejecución del Lab 6 en CloudWatch"
  policy      = data.aws_iam_policy_document.lambda_logs_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_logs_policy.arn
}

# Permiso de mínimo privilegio para enviar mensajes de fallo ÚNICAMENTE a la cola SQS lab6-events-dlq.
data "aws_iam_policy_document" "lambda_dlq_doc" {
  statement {
    sid       = "SendFailedEventsToLab6DlqOnly"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.dlq.arn]
  }
}

resource "aws_iam_policy" "lambda_dlq_policy" {
  name        = "lab6-resilient-worker-dlq-policy"
  description = "Permite enviar eventos fallidos a la cola SQS DLQ del Lab 6"
  policy      = data.aws_iam_policy_document.lambda_dlq_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_dlq_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_dlq_policy.arn
}

# ==========================================
# 4. FUNCIÓN LAMBDA (TIMEOUT Y MEMORIA)
# ==========================================

# Definimos un timeout corto de 3s y 128 MB de memoria para poder probar fácilmente
# qué ocurre cuando una tarea tarda 6s ("modo": "lento") y supera el límite.
resource "aws_lambda_function" "resilient_worker" {
  filename         = data.archive_file.resilient_worker_zip.output_path
  function_name    = "lab6-resilient-worker"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "resilient_worker.lambda_handler"
  source_code_hash = data.archive_file.resilient_worker_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 3
  memory_size      = 128

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs_attach,
    aws_iam_role_policy_attachment.lambda_dlq_attach,
    aws_cloudwatch_log_group.resilient_worker_logs
  ]
}

# ==========================================
# 5. REINTENTOS ASÍNCRONOS Y DESTINO DE FALLO (DLQ)
# ==========================================

# Configura el comportamiento de invocaciones asíncronas sobre la versión $LATEST:
# - maximum_retry_attempts = 2: AWS reintenta hasta 2 veces si falla la ejecución.
# - on_failure: si tras los reintentos sigue fallando, envía el destino de fallo a la cola SQS DLQ.
resource "aws_lambda_function_event_invoke_config" "async_retry_and_dlq" {
  function_name          = aws_lambda_function.resilient_worker.function_name
  maximum_event_age_in_seconds = 300
  maximum_retry_attempts       = 2

  destination_config {
    on_failure {
      destination = aws_sqs_queue.dlq.arn
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_dlq_attach]
}