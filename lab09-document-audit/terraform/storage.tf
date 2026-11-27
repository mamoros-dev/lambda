# storage.tf

# Genera un sufijo aleatorio hexadecimal para que el nombre del bucket S3
# sea único a nivel global en AWS y no falle por colisión de nombres.
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Bucket de entrada donde se suben los documentos a auditar.
# force_destroy = true facilita limpiar el lab con terraform destroy.
resource "aws_s3_bucket" "documents_bucket" {
  bucket        = "lab09-docs-audit-${random_id.bucket_suffix.hex}"
  force_destroy = true

  tags = {
    Name = "lab09-docs-audit-bucket"
  }
}

# Bloquea cualquier configuración accidental que exponga el bucket a internet.
resource "aws_s3_bucket_public_access_block" "documents_public_access_block" {
  bucket = aws_s3_bucket.documents_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Tabla DynamoDB para almacenar el historial/auditoría de cada documento.
# PAY_PER_REQUEST evita gestionar unidades de capacidad fijas.
resource "aws_dynamodb_table" "audit_table" {
  name         = "lab09-document-audit"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "document_id"

  attribute {
    name = "document_id"
    type = "S"
  }

  tags = {
    Name = "lab09-document-audit-table"
  }
}

# Dead Letter Queue (SQS) para recoger eventos que fallen tras los reintentos.
# Conserva los mensajes durante 24 horas (86400 s) para diagnóstico o reproceso.
resource "aws_sqs_queue" "audit_dlq" {
  name                      = "lab09-document-audit-dlq"
  message_retention_seconds = 86400

  tags = {
    Name = "lab09-document-audit-dlq"
  }
}