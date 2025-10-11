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
  default     = "lambda-payment"
}

variable "jar_file" {
  description = "Archivo JAR de la Lambda"
  type        = string
  default     = "lambda-payment-1.0-SNAPSHOT.jar"
}

# Recursos existentes
variable "start_payment_queue_url" {
  description = "URL de la cola SQS existente"
  type        = string
  default     = "https://sqs.us-east-1.amazonaws.com/872112794115/start-payment-queue"
}

variable "start_payment_queue_arn" {
  description = "ARN de la cola SQS existente"
  type        = string
  default     = "arn:aws:sqs:us-east-1:872112794115:start-payment-queue"
}

variable "card_table_name" {
  description = "Nombre de la tabla DynamoDB existente"
  type        = string
  default     = "card-table"
}

variable "card_table_arn" {
  description = "ARN de la tabla DynamoDB existente"
  type        = string
  default     = "arn:aws:dynamodb:us-east-1:872112794115:table/card-table"
}

variable "existing_api_id" {
  description = "ID de la API Gateway existente (card-api)"
  type        = string
  default     = "x8ewzbrr6k"
}

variable "new_stage_name" {
  description = "Nuevo stage a crear dentro del API Gateway"
  type        = string
  default     = "dev-payment"
}
