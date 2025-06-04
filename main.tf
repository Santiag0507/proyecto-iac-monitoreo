provider "aws" {
  region = var.region
}

# ========== IAM para Lambda ==========
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda-execution-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "lambda-dynamodb-permissions"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Scan"
        ],
        Resource = aws_dynamodb_table.iot_data.arn
      }
    ]
  })
}

# ========== DynamoDB ==========
resource "aws_dynamodb_table" "iot_data" {
  name         = "IoTDataTable"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "device_id"

  attribute {
    name = "device_id"
    type = "S"
  }
}

# ========== LAMBDAS ==========
locals {
  lambdas = {
    register_device    = "lambda_register_device.zip"
    store_metrics      = "lambda_store_metrics.zip"
    alert_system       = "lambda_alert_system.zip"
    get_dashboard      = "lambda_get_dashboard.zip"
    generate_report    = "lambda_generate_report.zip"
  }
}

resource "aws_lambda_function" "lambdas" {
  for_each         = local.lambdas
  function_name    = each.key
  filename         = "${path.module}/${each.value}"
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  role             = aws_iam_role.lambda_role.arn
  source_code_hash = filebase64sha256("${path.module}/${each.value}")

  environment {
    variables = {
      DYNAMO_TABLE = aws_dynamodb_table.iot_data.name
    }
  }
}

# ========== API Gateway ==========
resource "aws_apigatewayv2_api" "http_api" {
  name          = "iot-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  for_each             = aws_lambda_function.lambdas
  api_id               = aws_apigatewayv2_api.http_api.id
  integration_type     = "AWS_PROXY"
  integration_uri      = each.value.invoke_arn
  integration_method   = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "lambda_routes" {
  for_each  = aws_apigatewayv2_integration.lambda_integration
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /${each.key}"
  target    = "integrations/${each.value.id}"
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# ========== Permisos Lambda para API Gateway ==========
resource "aws_lambda_permission" "allow_apigw" {
  for_each     = aws_lambda_function.lambdas
  statement_id = "AllowExecutionFromAPIGateway-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}//"
}

# ========== CloudWatch Logs ==========
resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each          = aws_lambda_function.lambdas
  name              = "/aws/lambda/${each.value.function_name}"
  retention_in_days = 7
}
