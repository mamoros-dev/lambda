# layer.tf

# Empaqueta layer_build/ (que contiene python/audit_utils.py) en un archivo ZIP.
# Lambda montará el ZIP en /opt, dejando disponible /opt/python/audit_utils.py.
data "archive_file" "audit_layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/layer_build"
  output_path = "${path.module}/audit_layer.zip"
}

# Publica la versión de la Lambda Layer compatible con Python 3.11.
resource "aws_lambda_layer_version" "audit_layer" {
  layer_name          = "lab09-audit-utils-layer"
  description         = "Utilidades compartidas de auditoría documental en python/audit_utils.py"
  filename            = data.archive_file.audit_layer_zip.output_path
  source_code_hash    = data.archive_file.audit_layer_zip.output_base64sha256
  compatible_runtimes = ["python3.11"]
}