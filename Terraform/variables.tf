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
  default     = "lambda-check-balance"
}

variable "jar_file" {
  description = "Nombre del archivo JAR de la Lambda"
  type        = string
  default     = "lambda-check-balance-1.0-SNAPSHOT.jar"
}

variable "check_balance_queue_url" {
  description = "URL de la cola check-balance"
  type        = string
  default     = "https://sqs.us-east-1.amazonaws.com/872112794115/check-balance-queue"
}

variable "check_balance_queue_arn" {
  description = "ARN de la cola check-balance"
  type        = string
  default     = "arn:aws:sqs:us-east-1:872112794115:check-balance-queue"
}

variable "transaction_queue_url" {
  description = "URL de la cola transaction)"
  type        = string
  default     = "https://sqs.us-east-1.amazonaws.com/872112794115/transaction-queue"
}

variable "transaction_queue_arn" {
  description = "ARN de la cola transaction"
  type        = string
  default     = "arn:aws:sqs:us-east-1:872112794115:transaction-queue"
}

variable "card_table_name" {
  description = "Nombre de la tabla DynamoDB que contiene tarjetas"
  type        = string
  default     = "card-table"
}

variable "card_table_arn" {
  description = "ARN de la tabla card-table"
  type        = string
  default     = "arn:aws:dynamodb:us-east-1:872112794115:table/card-table"
}

variable "payment_table_name" {
  description = "Nombre de la tabla DynamoDB payment"
  type        = string
  default     = "payment"
}

variable "payment_table_arn" {
  description = "ARN de la tabla payment"
  type        = string
  default     = "arn:aws:dynamodb:us-east-1:872112794115:table/payment"
}

variable "lambda_memory" {
  description = "Memoria para Lambda"
  type        = number
  default     = 512
}

variable "lambda_timeout" {
  description = "Timeout para Lambda"
  type        = number
  default     = 30
}
