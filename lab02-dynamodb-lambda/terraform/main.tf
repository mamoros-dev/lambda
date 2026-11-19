# ==========================================
# 1. BASE DE DATOS NOSQL (AMAZON DYNAMODB)
# ==========================================

# Crea la tabla donde se guardarán y consultarán los eventos desde Lambda.
# PAY_PER_REQUEST evita tener que reservar capacidad fija de lectura/escritura.
resource "aws_dynamodb_table" "eventos_table" {
  name         = "lab2-eventos-demo"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"

  # Solo declaramos en attribute los atributos que forman parte de las claves (hash/range)
  attribute {
    name = "event_id"
    type = "S" # S = String (texto)
  }

  tags = {
    Laboratorio = "Lab2-DynamoDB"
  }
}

# ==========================================
# 2. IDENTIDAD Y PERMISOS (IAM)
# ==========================================

# Política de confianza (Trust Policy): permite que AWS Lambda asuma este rol.
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

# Rol IAM que usará la función Lambda durante su ejecución.
resource "aws_iam_role" "dynamodb_lambda_role" {
  name               = "lab2-dynamodb-handler-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# --- Política 1: Permisos exclusivos para CloudWatch Logs ---
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
  name        = "lab2-dynamodb-logs-policy"
  description = "Permite a la Lambda escribir sus logs en CloudWatch"
  policy      = data.aws_iam_policy_document.lambda_logs_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs_attach" {
  role       = aws_iam_role.dynamodb_lambda_role.name
  policy_arn = aws_iam_policy.lambda_logs_policy.arn
}

# --- Política 2: Permisos mínimos para leer y escribir en nuestra tabla DynamoDB ---
data "aws_iam_policy_document" "dynamodb_access_doc" {
  statement {
    sid    = "ReadAndWriteEventosTableOnly"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem"
    ]
    # Restringimos el permiso exclusivamente a la tabla creada en este laboratorio
    resources = [aws_dynamodb_table.eventos_table.arn]
  }
}

resource "aws_iam_policy" "dynamodb_access_policy" {
  name        = "lab2-dynamodb-table-access-policy"
  description = "Permite PutItem y GetItem únicamente sobre la tabla lab2-eventos-demo"
  policy      = data.aws_iam_policy_document.dynamodb_access_doc.json
}

resource "aws_iam_role_policy_attachment" "dynamodb_access_attach" {
  role       = aws_iam_role.dynamodb_lambda_role.name
  policy_arn = aws_iam_policy.dynamodb_access_policy.arn
}

# ==========================================
# 3. EMPAQUETADO Y OBSERVABILIDAD (ZIP + LOGS)
# ==========================================

# Empaqueta dynamodb_handler.py en un archivo zip dentro de la carpeta del proyecto.
data "archive_file" "dynamodb_handler_zip" {
  type        = "zip"
  source_file = "${path.module}/dynamodb_handler.py"
  output_path = "${path.module}/dynamodb_handler.zip"
}

# Crea el Log Group antes de invocar la función para fijar la retención a 7 días
# y evitar que los logs se acumulen indefinidamente sin control de costes.
resource "aws_cloudwatch_log_group" "dynamodb_handler_logs" {
  name              = "/aws/lambda/lab2-dynamodb-handler"
  retention_in_days = 1
}

# ==========================================
# 4. COMPUTACIÓN SERVERLESS (AWS LAMBDA)
# ==========================================

# Crea la función Lambda que leerá y escribirá registros en DynamoDB.
resource "aws_lambda_function" "dynamodb_handler" {
  filename         = data.archive_file.dynamodb_handler_zip.output_path
  function_name    = "lab2-dynamodb-handler"
  role             = aws_iam_role.dynamodb_lambda_role.arn
  handler          = "dynamodb_handler.lambda_handler"
  source_code_hash = data.archive_file.dynamodb_handler_zip.output_base64sha256
  runtime          = "python3.11"

  # Garantizamos que los permisos IAM y el Log Group existan antes de crear la Lambda.
  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs_attach,
    aws_iam_role_policy_attachment.dynamodb_access_attach,
    aws_cloudwatch_log_group.dynamodb_handler_logs
  ]
}