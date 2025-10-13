terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.region
}

# ===============================
# 🧠 IAM Role para Lambda
# ===============================
resource "aws_iam_role" "lambda_role" {
  name = "lambda-transaction-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# ===============================
# 🔐 Política IAM
# ===============================
resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda-transaction-policy"
  description = "Permisos para Lambda Transaction"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ✅ DynamoDB (lectura/escritura en tabla payment)
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/${var.payment_table_name}"
      },

      # ✅ SQS (recibir de transaction queue y enviar a DLQ)
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:SendMessage"
        ]
        Resource = [
          var.transaction_queue_arn,
          var.dead_letter_queue_arn
        ]
      },

      # ✅ CloudWatch logs
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },

      # ✅ CloudWatch métricas personalizadas
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },

      # ✅ Permitir acceso a internet (si usa VPC)
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

# Vincular política al rol
resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# ===============================
# ⚙️ Lambda Function: Transaction
# ===============================
resource "aws_lambda_function" "transaction_lambda" {
  function_name = "TransactionLambda"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "nodejs20.x"
  timeout       = 20
  handler       = "dist/lambda/transaction.handler"

  filename         = "${path.module}/../transaction.zip"
  source_code_hash = filebase64sha256("${path.module}/../transaction.zip")

  environment {
    variables = {
      PAYMENT_TABLE          = var.payment_table_name
      TRANSACTION_QUEUE_URL  = var.transaction_queue_url
      TRANSACTION_QUEUE_ARN  = var.transaction_queue_arn
      DEAD_LETTER_QUEUE_URL  = var.dead_letter_queue_url
      DEAD_LETTER_QUEUE_ARN  = var.dead_letter_queue_arn
      PAYMENT_API_URL        = "https://x8ewzbrr6k.execute-api.us-east-1.amazonaws.com/dev/transactions/purchase"
    }
  }
}

# ===============================
# 🔔 Permitir que SQS invoque la Lambda
# ===============================
resource "aws_lambda_permission" "allow_sqs_invoke" {
  statement_id  = "AllowSQSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transaction_lambda.function_name
  principal     = "sqs.amazonaws.com"
  source_arn    = var.transaction_queue_arn
}

# ===============================
# 🔄 Event Source Mapping (SQS → Lambda)
# ===============================
resource "aws_lambda_event_source_mapping" "sqs_to_lambda" {
  event_source_arn = var.transaction_queue_arn
  function_name    = aws_lambda_function.transaction_lambda.arn
  batch_size       = 1
  enabled          = true
}

# ===============================
# 💀 Dead Letter Queue
# ===============================
resource "aws_sqs_queue" "dead_letter_queue" {
  name = "error-transaction-sqs"
}

# Variable de salida para URL y ARN de DLQ
output "dead_letter_queue_url" {
  value = aws_sqs_queue.dead_letter_queue.id
}

output "dead_letter_queue_arn" {
  value = aws_sqs_queue.dead_letter_queue.arn
}
