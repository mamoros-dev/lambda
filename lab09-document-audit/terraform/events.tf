# events.tf

data "aws_caller_identity" "current" {}

# Permite que el bucket S3 del Lab 09 invoque la función Lambda al crear objetos.
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id   = "AllowExecutionFromLab09S3Bucket"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.document_audit.function_name
  principal      = "s3.amazonaws.com"
  source_arn     = aws_s3_bucket.documents_bucket.arn
  source_account = data.aws_caller_identity.current.account_id
}

# Dispara la Lambda de forma asíncrona cada vez que se crea un objeto en el bucket.
resource "aws_s3_bucket_notification" "document_uploaded" {
  bucket = aws_s3_bucket.documents_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.document_audit.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}