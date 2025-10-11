# Permite que Lambda asuma el rol
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Políticas para que Lambda acceda a DynamoDB y SQS existentes
data "aws_iam_policy_document" "lambda_permissions" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:GetQueueUrl",
      "sqs:GetQueueAttributes"
    ]
    resources = [var.start_payment_queue_arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan"
    ]
    resources = [var.card_table_arn]
  }
}
