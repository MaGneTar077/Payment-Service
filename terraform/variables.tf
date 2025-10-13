# ======================================
# 🌎 Región
# ======================================
variable "region" {
  description = "Región de AWS donde se despliega la infraestructura"
  type        = string
  default     = "us-east-1"
}

# ======================================
# 💳 Tabla DynamoDB
# ======================================
variable "payment_table_name" {
  description = "Nombre de la tabla DynamoDB donde se guardan los pagos"
  type        = string
  default     = "payment"
}

# ======================================
# 🔄 Cola principal de transacciones
# ======================================
variable "transaction_queue_url" {
  description = "URL de la cola SQS transaction-queue"
  type        = string
  default     = "https://sqs.us-east-1.amazonaws.com/872112794115/transaction-queue"
}

variable "transaction_queue_arn" {
  description = "ARN de la cola SQS transaction-queue"
  type        = string
  default     = "arn:aws:sqs:us-east-1:872112794115:transaction-queue"
}

# ======================================
# 💀 Dead Letter Queue (para errores)
# ======================================
variable "dead_letter_queue_url" {
  description = "URL de la cola SQS para mensajes fallidos"
  type        = string
  default     = "https://sqs.us-east-1.amazonaws.com/872112794115/error-transaction-sqs"
}

variable "dead_letter_queue_arn" {
  description = "ARN de la cola SQS para mensajes fallidos"
  type        = string
  default     = "arn:aws:sqs:us-east-1:872112794115:error-transaction-sqs"
}

# ======================================
# 🏦 API del sistema core bancario
# ======================================
variable "payment_api_url" {
  description = "URL del endpoint POST /transactions/purchase del core bancario"
  type        = string
  default     = "https://x8ewzbrr6k.execute-api.us-east-1.amazonaws.com/dev/transactions/purchase"
}
