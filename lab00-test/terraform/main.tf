# ==========================================
# 1. SEGURIDAD E IDENTIDAD (IAM)
# ==========================================

# 1. Política de Confianza (Trust Policy): Permite que el servicio Lambda asuma este rol
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# 2. Creación del Rol de IAM
resource "aws_iam_role" "lambda_exec_role" {
  name               = "lambda_execution_role_demo"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# 3. Política de Permisos para CloudWatch Logs (Mínimo Privilegio)
data "aws_iam_policy_document" "lambda_logging_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

# 4. Creación de la política como recurso gestionado
resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging_policy_demo"
  path        = "/"
  description = "IAM policy for logging from a lambda"
  policy      = data.aws_iam_policy_document.lambda_logging_policy.json
}

# 5. Adjuntar la política de logs al rol de ejecución de la Lambda
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}


# ==========================================
# 2. COMPUTACIÓN SERVERLESS (LAMBDA)
# ==========================================
# 1. Empaquetar automáticamente el código Python en un archivo .zip
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# 2. Desplegar la función AWS Lambda
resource "aws_lambda_function" "mi_primera_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "funcion_lambda_demo"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "lambda_function.lambda_handler" # Archivo.funcion
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.11"
  #kms_key_arn      = aws_kms_key.lambda_kms_key.arn # <-- AÑADE ESTA LÍNEA POR SEGURIDAD KMS

  environment {
    variables = {
      ENTORNO = "dev"
    }
  }
}


# ==========================================
# 3. OBSERVABILIDAD (CLOUDWATCH)
# ==========================================

# 1. CloudWatch Log Group con retención explícita de 7 días
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/funcion_lambda_demo"
  retention_in_days = 7
}

# 2. Alarma de CloudWatch para detectar errores en la Lambda
resource "aws_cloudwatch_metric_alarm" "lambda_error_alarm" {
  alarm_name          = "lambda-error-alarm-demo"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alerta si la función Lambda registra uno o más errores en un intervalo de 1 minuto."

  dimensions = {
    FunctionName = aws_lambda_function.mi_primera_lambda.function_name
  }
}

# ==========================================
# 4. REDES Y SEGURIDAD (SECURITY GROUPS)
# ==========================================
# 1. Clave de cifrado KMS (Customer Managed Key) para variables de entorno y logs
# resource "aws_kms_key" "lambda_kms_key" {
#   description             = "Clave KMS para cifrar variables de entorno de la Lambda"
#   deletion_window_in_days = 1
#   enable_key_rotation     = true # Buena práctica de seguridad en entrevistas
# }

# resource "aws_kms_alias" "lambda_kms_alias" {
#   name          = "alias/lambda-demo-key"
#   target_key_id = aws_kms_key.lambda_kms_key.key_id
# }

# 2. Security Group restrictivo (preparado para entornos VPC)
# Usamos la VPC por defecto de tu cuenta para este laboratorio
data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "lambda_sg" {
  name        = "lambda-security-group-demo"
  description = "Security Group restrictivo para AWS Lambda"
  vpc_id      = data.aws_vpc.default.id

  # Regla de salida (Egress): Solo permitimos tráfico HTTPS saliente (puerto 443)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Permitir solo llamadas salientes HTTPS seguras"
  }
}