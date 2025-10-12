provider "aws" {
  region = "us-east-1"
}

# 🟧 Role para la Lambda
resource "aws_iam_role" "lambda_start_payment_role" {
  name = "lambda-start-payment-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = { Service = "lambda.amazonaws.com" },
      Effect   = "Allow"
    }]
  })
}

# 🟨 Políticas para DynamoDB, SQS y CloudWatch Logs
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda-start-payment-policy"
  role = aws_iam_role.lambda_start_payment_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow",
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"],
        Resource = [
          "arn:aws:dynamodb:*:*:table/${var.payment_table}",
          "arn:aws:dynamodb:*:*:table/${var.card_table}"
        ]
      },
      {
        Effect   = "Allow",
        Action   = ["sqs:SendMessage"],
        Resource = var.start_payment_queue_arn
      },
      {
        Effect   = "Allow",
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"],
        Resource = var.start_payment_queue_arn
      },
      {
        Effect   = "Allow",
        Action   = ["sqs:SendMessage"],
        Resource = var.check_balance_queue_arn
      }
    

    ]
  })
}

resource "aws_lambda_function" "start_payment" {
  function_name = "start-payment"
  role          = aws_iam_role.lambda_start_payment_role.arn
  handler       = "dist/lambda/start_payment.handler" 
  runtime       = "nodejs20.x"

  # 👇 Ambos deben apuntar al mismo archivo ZIP
  filename         = "${path.module}/../start_payment.zip"
  source_code_hash = filebase64sha256("${path.module}/../start_payment.zip")

  environment {
    variables = {
      PAYMENT_TABLE            = var.payment_table
      CARD_TABLE               = var.card_table
      START_PAYMENT_QUEUE_URL  = var.start_payment_queue_url
      START_PAYMENT_QUEUE_ARN  = var.start_payment_queue_arn
      CHECK_BALANCE_QUEUE_URL   = var.check_balance_queue_url
      CHECK_BALANCE_QUEUE_ARN   = var.check_balance_queue_arn
    }
  }
}



# 🟦 CloudWatch Log Group para la Lambda start-payment
resource "aws_cloudwatch_log_group" "lambda_start_payment_logs" {
  name              = "/aws/lambda/${aws_lambda_function.start_payment.function_name}"
  retention_in_days = 14 # puedes poner 7, 30, 90, etc.
}

# 🟢 Trigger SQS → Lambda
resource "aws_lambda_event_source_mapping" "start_payment_trigger" {
  event_source_arn  = var.start_payment_queue_arn
  function_name     = aws_lambda_function.start_payment.arn
  batch_size        = 1
  enabled           = true
}