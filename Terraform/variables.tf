variable "region" {
  description = "Región AWS"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente (dev/test/prod)"
  type        = string
  default     = "dev"
}

variable "lambda_name" {
  description = "Nombre de la función Lambda"
  type        = string
  default     = "lambda-check-status-payment"
}

variable "jar_file" {
  description = "Archivo JAR de la Lambda"
  type        = string
  default     = "lambda-check-status-payment-1.0-SNAPSHOT.jar"
}

variable "existing_api_id" {
  description = "ID de la API Gateway existente (card-api)"
  type        = string
  default     = "x8ewzbrr6k"
}

variable "payment_table_name" {
  description = "Nombre de la tabla DynamoDB de pagos"
  type        = string
  default     = "payment"
}

variable "payment_table_arn" {
  description = "ARN de la tabla DynamoDB de pagos"
  type        = string
  default     = "arn:aws:dynamodb:us-east-1:872112794115:table/payment"
}

variable "new_stage_name" {
  description = "Nombre del nuevo stage"
  type        = string
  default     = "dev-status-payment"
}
