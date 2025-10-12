variable "payment_table" {
  description = "Nombre de la tabla DynamoDB de pagos"
  type        = string
  default     = "payment"
}

variable "card_table" {
  description = "Nombre de la tabla DynamoDB de tarjetas"
  type        = string
  default     = "card-table"
}

variable "start_payment_queue_url" {
  description = "URL de la cola SQS start-payment"
  type        = string
  default     = "https://sqs.us-east-1.amazonaws.com/872112794115/start-payment-queue"
}

variable "start_payment_queue_arn" {
  description = "ARN de la cola SQS start-payment"
  type        = string
  default     = "arn:aws:sqs:us-east-1:872112794115:start-payment-queue"
}

variable "check_balance_queue_url" {
  description = "URL de la cola SQS check-balance"
  type        = string
  default     = "https://sqs.us-east-1.amazonaws.com/872112794115/check-balance-queue"
}

variable "check_balance_queue_arn" {
  description = "ARN de la cola SQS check-balance"
  type        = string
  default     = "arn:aws:sqs:us-east-1:872112794115:check-balance-queue"
}
