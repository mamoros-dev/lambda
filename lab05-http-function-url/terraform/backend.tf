terraform {
  backend "s3" {
    bucket       = "miguel-labs-terraform-state" # Asegúrate de que este bucket exista en tu cuenta de AWS
    key          = "lab05-http-function-url/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true # locking en el mismo bucket S3
    # dynamodb_table = "miguel-labs-terraform-locks" # locking en DynamoDB
    encrypt = true
  }
}