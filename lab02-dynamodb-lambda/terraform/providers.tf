# --- Este archivo define la configuración del proveedor de AWS para Terraform. Especifica la versión requerida de Terraform y el proveedor de AWS, así como la región de AWS que se utilizará para la creación de recursos. El bloque del proveedor configura el proveedor de AWS con la región especificada (eu-west-1) para todos los recursos definidos en esta configuración de Terraform.
terraform {
  required_version = ">= 1.9"
  required_providers {
    # Proveedor oficial de AWS para crear buckets, roles IAM, funciones Lambda, etc.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}
