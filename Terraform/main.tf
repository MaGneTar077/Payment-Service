#  IAM ROLE Y POLÍTICAS
resource "aws_iam_role" "lambda_role" {
  name               = "lambda_check_status_payment_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "lambda_check_status_payment_policy"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

#  LAMBDA FUNCTION
resource "aws_lambda_function" "check_status_lambda" {
  function_name = var.lambda_name
  filename      = abspath("${path.module}/../lambda-check-status-payment/target/${var.jar_file}")
  handler       = "org.example.CheckStatusPaymentHandler::handleRequest"
  runtime       = "java17"
  memory_size   = 512
  timeout       = 25
  role          = aws_iam_role.lambda_role.arn

  source_code_hash = filebase64sha256(abspath("${path.module}/../lambda-check-status-payment/target/${var.jar_file}"))

  environment {
    variables = {
      PAYMENT_TABLE_NAME = var.payment_table_name
    }
  }

  tags = {
    Name        = "LambdaCheckStatusPayment"
    Environment = var.environment
  }
}

# Referencia a la API existente card-api
data "aws_api_gateway_rest_api" "card_api" {
  name = "card-api"
}

# Crear recurso /status
resource "aws_api_gateway_resource" "status_resource" {
  rest_api_id = var.existing_api_id
  parent_id   = data.aws_api_gateway_rest_api.card_api.root_resource_id
  path_part   = "status"
}

# Crear subrecurso /{traceId}
resource "aws_api_gateway_resource" "status_traceid_resource" {
  rest_api_id = var.existing_api_id
  parent_id   = aws_api_gateway_resource.status_resource.id
  path_part   = "{traceId}"
}

# Crear metodo get
resource "aws_api_gateway_method" "status_method" {
  rest_api_id   = var.existing_api_id
  resource_id   = aws_api_gateway_resource.status_traceid_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# Integración Lambda AWS_PROXY
resource "aws_api_gateway_integration" "status_integration" {
  rest_api_id             = var.existing_api_id
  resource_id             = aws_api_gateway_resource.status_traceid_resource.id
  http_method             = aws_api_gateway_method.status_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.check_status_lambda.invoke_arn
}

# Permitir invocar Lambda desde API Gateway
resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvokeCheckStatus"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.check_status_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:872112794115:${var.existing_api_id}/*/GET/status/*"
}

# Desplegar los cambios
resource "aws_api_gateway_deployment" "status_deployment" {
  rest_api_id = var.existing_api_id
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.status_integration.id,
      aws_api_gateway_method.status_method.id
    ]))
  }

  depends_on = [
    aws_api_gateway_integration.status_integration
  ]
}

# Crear nuevo stage
resource "aws_api_gateway_stage" "dev_status_payment_stage" {
  rest_api_id   = var.existing_api_id
  deployment_id = aws_api_gateway_deployment.status_deployment.id
  stage_name    = var.new_stage_name
}

# Output
output "api_endpoint" {
  description = "Endpoint del recurso GET /status/{traceId}"
  value       = "https://${var.existing_api_id}.execute-api.${var.region}.amazonaws.com/${var.new_stage_name}/status/{traceId}"
}

