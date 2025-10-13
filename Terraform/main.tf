resource "aws_iam_role" "lambda_role" {
  name               = "${var.lambda_name}_execution_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "${var.lambda_name}_policy"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "check_balance" {
  function_name = var.lambda_name
  filename      = abspath("${path.module}/../lambda-check-balance/target/${var.jar_file}")
  handler       = "org.example.CheckBalanceHandler::handleRequest"
  runtime       = "java17"
  memory_size   = var.lambda_memory
  timeout       = var.lambda_timeout
  role          = aws_iam_role.lambda_role.arn

  source_code_hash = filebase64sha256(abspath("${path.module}/../lambda-check-balance/target/${var.jar_file}"))

  environment {
    variables = {
      CARD_TABLE_NAME        = var.card_table_name
      PAYMENT_TABLE_NAME     = var.payment_table_name
      TRANSACTION_QUEUE_URL  = var.transaction_queue_url
    }
  }

  tags = {
    Name        = var.lambda_name
    Environment = var.environment
  }
}

resource "aws_lambda_event_source_mapping" "sqs_check_balance" {
  event_source_arn  = var.check_balance_queue_arn
  function_name     = aws_lambda_function.check_balance.arn
  enabled           = true
  batch_size        = 5     # cuantos mensajes trae por invocación
  maximum_batching_window_in_seconds = 0
}

# Outputs
output "lambda_function_name" {
  description = "Nombre de la Lambda creada"
  value       = aws_lambda_function.check_balance.function_name
}

output "sqs_event_source_mapping_id" {
  description = "Event source mapping id (SQS -> Lambda)"
  value       = aws_lambda_event_source_mapping.sqs_check_balance.id
}
