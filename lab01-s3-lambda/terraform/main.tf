# Genera un identificador aleatorio de 4 bytes (8 caracteres hexadecimales)
# para que el nombre del bucket S3 sea único a nivel global en AWS.
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# ==========================================
# 1. ALMACENAMIENTO (AMAZON S3)
# ==========================================

# Crea el bucket S3 donde se subirán los archivos que dispararán la Lambda.
# force_destroy = true permite borrar el bucket con terraform destroy aunque tenga objetos dentro.
resource "aws_s3_bucket" "uploads_bucket" {
  bucket        = "lab1-s3-lambda-uploads-${random_id.bucket_suffix.hex}"
  force_destroy = true # Facilita el terraform destroy en laboratorio
}

# Bloquea cualquier configuración accidental que exponga el bucket o sus objetos a internet.
resource "aws_s3_bucket_public_access_block" "uploads_bucket_pab" {
  bucket = aws_s3_bucket.uploads_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ==========================================
# 2. IDENTIDAD Y PERMISOS (IAM)
# ==========================================

# Política de confianza (Trust Policy): permite que el servicio AWS Lambda asuma este rol.
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

# Rol de IAM que usará la función Lambda durante su ejecución.
resource "aws_iam_role" "s3_lambda_role" {
  name               = "lab1-s3-processor-role-${random_id.bucket_suffix.hex}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# --- Política 1: Permisos exclusivos para escribir logs en CloudWatch ---
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

# Crea la política de logs como recurso gestionado independiente en IAM.
resource "aws_iam_policy" "lambda_logs_policy" {
  name        = "lab1-s3-lambda-logs-policy-${random_id.bucket_suffix.hex}"
  description = "Permite a la Lambda crear grupos/flujos de logs y enviar eventos a CloudWatch"
  policy      = data.aws_iam_policy_document.lambda_logs_doc.json
}

# Adjunta la política de logs al rol de la Lambda.
resource "aws_iam_role_policy_attachment" "lambda_logs_attach" {
  role       = aws_iam_role.s3_lambda_role.name
  policy_arn = aws_iam_policy.lambda_logs_policy.arn
}

# --- Política 2: Permisos exclusivos de lectura sobre nuestro bucket S3 ---
data "aws_iam_policy_document" "s3_read_doc" {
  statement {
    sid    = "ReadObjectsFromLabBucket"
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    # Limitamos el permiso únicamente a los objetos dentro de nuestro bucket
    resources = ["${aws_s3_bucket.uploads_bucket.arn}/*"]
  }
}

# Crea la política de lectura S3 como recurso gestionado independiente en IAM.
resource "aws_iam_policy" "s3_read_policy" {
  name        = "lab1-s3-lambda-s3-read-policy-${random_id.bucket_suffix.hex}"
  description = "Permite leer metadatos y objetos solo del bucket de laboratorio"
  policy      = data.aws_iam_policy_document.s3_read_doc.json
}

# Adjunta la política de lectura S3 al rol de la Lambda.
resource "aws_iam_role_policy_attachment" "s3_read_attach" {
  role       = aws_iam_role.s3_lambda_role.name
  policy_arn = aws_iam_policy.s3_read_policy.arn
}

# ==========================================
# 3. EMPAQUETADO Y OBSERVABILIDAD (ZIP + LOGS)
# ==========================================

# Comprime automáticamente s3_processor.py en un archivo s3_processor.zip
# dentro de la misma carpeta del módulo (${path.module}).
data "archive_file" "s3_processor_zip" {
  type        = "zip"
  source_file = "${path.module}/s3_processor.py"
  output_path = "${path.module}/s3_processor.zip"
}

# Crea explícitamente el Log Group antes de invocar la Lambda para controlar
# la retención a 7 días desde el primer momento y evitar retención infinita.
resource "aws_cloudwatch_log_group" "s3_processor_logs" {
  name              = "/aws/lambda/lab1-s3-processor-${random_id.bucket_suffix.hex}"
  retention_in_days = 1
}

# ==========================================
# 4. COMPUTACIÓN SERVERLESS (AWS LAMBDA)
# ==========================================

# Crea la función Lambda en Python 3.11 usando el rol IAM de la primera parte.
resource "aws_lambda_function" "s3_processor" {
  filename         = data.archive_file.s3_processor_zip.output_path
  function_name    = "lab1-s3-processor-${random_id.bucket_suffix.hex}"
  role             = aws_iam_role.s3_lambda_role.arn
  handler          = "s3_processor.lambda_handler"
  source_code_hash = data.archive_file.s3_processor_zip.output_base64sha256
  runtime          = "python3.11"

  # Garantizamos que los adjuntos IAM y el Log Group existan antes de crear la función.
  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs_attach,
    aws_iam_role_policy_attachment.s3_read_attach,
    aws_cloudwatch_log_group.s3_processor_logs
  ]
}

# ==========================================
# 5. DISPARADOR DESDE S3 (PERMISO + EVENTO)
# ==========================================

# Autoriza explícitamente al servicio s3.amazonaws.com a invocar esta Lambda,
# restringiendo el origen (source_arn) únicamente a nuestro bucket de laboratorio.
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.uploads_bucket.arn
}

# Configura el bucket para que cada vez que se cree un objeto (s3:ObjectCreated:*)
# envíe un evento a nuestra función Lambda.
resource "aws_s3_bucket_notification" "on_file_upload" {
  bucket = aws_s3_bucket.uploads_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_processor.arn
    events              = ["s3:ObjectCreated:*"]
    # filter_suffix       = ".txt" # Solo dispara la Lambda si el archivo acaba en .txt
  }

  # Espera a que exista el permiso de invocación; de lo contrario S3 rechaza
  # registrar la notificación porque no puede verificar que tiene permiso para llamar a la Lambda.
  depends_on = [aws_lambda_permission.allow_s3_invoke]
}
