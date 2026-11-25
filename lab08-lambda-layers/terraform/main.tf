# ==========================================
# 1. EMPAQUETADO DE LA CAPA (LAMBDA LAYER)
# ==========================================

# Empaqueta el contenido de layer_build (que contiene la carpeta python/helpers.py)
# en un archivo layer.zip. Al cambiar helpers.py, cambia output_base64sha256 y se
# publica una nueva versión de la capa.
data "archive_file" "shared_layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/layer_build"
  output_path = "${path.module}/layer.zip"
}

# Publica una versión de Lambda Layer compatible con Python 3.11.
resource "aws_lambda_layer_version" "shared_layer" {
  layer_name          = "lab8-shared-utils-layer"
  description         = "Utilidades compartidas en python/helpers.py para el Lab 8"
  filename            = data.archive_file.shared_layer_zip.output_path
  source_code_hash    = data.archive_file.shared_layer_zip.output_base64sha256
  compatible_runtimes = ["python3.11"]
}

# ==========================================
# 2. EMPAQUETADO DE LA FUNCIÓN Y LOGS
# ==========================================

# Empaqueta únicamente layer_handler.py (sin duplicar la capa dentro del .zip).
data "archive_file" "lambda_function_zip" {
  type        = "zip"
  source_file = "${path.module}/layer_handler.py"
  output_path = "${path.module}/function.zip"
}

# Log Group con retención de 7 días para revisar ejecuciones y posibles errores de importación.
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/lab8-layers-demo"
  retention_in_days = 7
}

# ==========================================
# 3. ROL IAM DE EJECUCIÓN DE LA LAMBDA
# ==========================================

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

resource "aws_iam_role" "lambda_exec_role" {
  name               = "lab8-layers-demo-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

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
  name        = "lab8-layers-demo-logs-policy"
  description = "Permite escribir logs de ejecución del Lab 8 en CloudWatch"
  policy      = data.aws_iam_policy_document.lambda_logs_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_logs_policy.arn
}

# ==========================================
# 4. FUNCIÓN LAMBDA ENLAZADA A LA CAPA
# ==========================================

resource "aws_lambda_function" "layers_demo" {
  filename         = data.archive_file.lambda_function_zip.output_path
  function_name    = "lab8-layers-demo"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "layer_handler.lambda_handler"
  source_code_hash = data.archive_file.lambda_function_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 10
  memory_size      = 128

  # Asocia la versión publicada de la Lambda Layer.
  layers = [aws_lambda_layer_version.shared_layer.arn]

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs_attach,
    aws_cloudwatch_log_group.lambda_logs
  ]
}