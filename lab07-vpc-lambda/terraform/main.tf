# ==========================================
# 4. EMPAQUETADO Y LOGS
# ==========================================
# Empaqueta vpc_checker.py en un archivo ZIP para subirlo a Lambda
data "archive_file" "vpc_checker_zip" {
  type        = "zip"
  source_file = "${path.module}/vpc_checker.py"
  output_path = "${path.module}/vpc_checker.zip"
}

# Grupo de logs de CloudWatch con retención de 7 días
resource "aws_cloudwatch_log_group" "vpc_checker_logs" {
  name              = "/aws/lambda/lab7-lambda-vpc"
  retention_in_days = 1 #7
}

# ==========================================
# 5. ROL IAM Y POLÍTICAS (PERMISOS DE RED Y S3)
# ==========================================
# Política de confianza para permitir que el servicio Lambda asuma el rol
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
  name               = "lab7-lambda-vpc-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Permisos para escribir logs en CloudWatch y crear/gestionar ENIs en la VPC
# Política para logs y (CRÍTICO) permisos de red para ENIs dentro de la VPC
data "aws_iam_policy_document" "lambda_network_doc" {
  # Permisos básicos de CloudWatch Logs
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
  
  # Permisos necesarios para gestionar ENIs en la VPC (asignar/liberar IPs privadas)
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
}

resource "aws_iam_policy" "lambda_network_policy" {
  name        = "lab7-lambda-vpc-network-policy"
  description = "Permite logs y acceso a VPC para Lambda"
  policy      = data.aws_iam_policy_document.lambda_network_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_network_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_network_policy.arn
}

# Permisos para listar buckets y leer objetos en S3 desde la Lambda
# Permiso de mínimo privilegio para listar y leer objetos en TODOS los buckets de la cuenta
data "aws_iam_policy_document" "lambda_s3_read_doc" {
  statement {
    sid       = "ListAndReadS3"
    effect    = "Allow"
    actions   = [
      "s3:ListBucket",
      "s3:GetObject"
    ]
    resources = [
      "arn:aws:s3:::*",
      "arn:aws:s3:::*/*"
    ]
  }
}

resource "aws_iam_policy" "lambda_s3_read_policy" {
  name        = "lab7-lambda-s3-read-policy"
  description = "Permite leer de S3 desde la VPC"
  policy      = data.aws_iam_policy_document.lambda_s3_read_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_s3_read_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_s3_read_policy.arn
}

# ==========================================
# 6. FUNCIÓN LAMBDA CON CONFIGURACIÓN DE VPC
# ==========================================
# Función Lambda conectada a las subredes privadas mediante vpc_config
resource "aws_lambda_function" "vpc_checker" {
  filename         = data.archive_file.vpc_checker_zip.output_path
  function_name    = "lab7-lambda-vpc"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "vpc_checker.lambda_handler"
  source_code_hash = data.archive_file.vpc_checker_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 15 # Damos un poco más de tiempo por si la inicialización en la VPC es más lenta

  # CONEXIÓN A LA VPC
  vpc_config {
    # IDs de las subredes privadas (mínimo 2 para alta disponibilidad)
    subnet_ids = [
      aws_subnet.private_subnet_a.id,
      aws_subnet.private_subnet_b.id
    ]
    # ID del Security Group que permite el tráfico de salida
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_network_attach,
    aws_iam_policy.lambda_s3_read_policy,
    aws_cloudwatch_log_group.vpc_checker_logs,
    aws_vpc_endpoint.s3_endpoint
  ]
}