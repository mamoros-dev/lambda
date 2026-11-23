# variable "demo_api_token" para almacenar el token de ejemplo en SSM Parameter Store.
variable "demo_api_token" {
  description = "Token de ejemplo para el Lab 4 de Lambda (almacenado en SSM Parameter Store como SecureString)."
  type        = string
  sensitive   = true
  default     = "token-demo-lab4-987654"
}