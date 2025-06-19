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

# Obtener la VPC por defecto
data "aws_vpc" "default" {
  default = true
}

# Obtener todas las subnets de esa VPC
data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
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
      },
      {
        Effect = "Allow",
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Resource = aws_sqs_queue.iot_alert_queue.arn
      },
      {
        Effect = "Allow",
        Action = [
          "sns:Publish"
        ],
        Resource = aws_sns_topic.iot_alert_topic.arn
      }
    ]
  })
}

# ========== DynamoDB ==========
resource "aws_kms_key" "dynamodb_key" {
  description             = "CMK for DynamoDB encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "default"
    Statement = [
      {
        Sid       = "Enable IAM User Permissions"
        Effect    = "Allow"
        Principal = {
          AWS = "*"
        }
        Action    = "kms:*"
        Resource  = "*"
      }
    ]
  })
}


resource "aws_dynamodb_table" "iot_data" {
  name         = "IoTDataTable"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "device_id"

  attribute {
    name = "device_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_key.arn
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

resource "aws_kms_key" "lambda_env_key" {
  description             = "KMS key for encrypting Lambda environment variables"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "default"
    Statement = [
      {
        Sid       = "Enable IAM User Permissions"
        Effect    = "Allow"
        Principal = {
          AWS = "*"
        }
        Action    = "kms:*"
        Resource  = "*"
      }
    ]
  })
}


resource "aws_lambda_code_signing_config" "signing_config" {
  allowed_publishers {
    signing_profile_version_arns = [
      "arn:aws:signer:us-east-1:123456789012:signing-profile/my-signing-profile"
    ]
  }

  policies {
    untrusted_artifact_on_deployment = "Enforce"
  }
}

resource "aws_security_group" "lambda_sg" {
  name        = "lambda-security-group"
  description = "Security group for Lambda"
  vpc_id      = data.aws_vpc.default.id

  # checkov:skip=CKV_AWS_382 Reason: Se permite salida total en entorno de pruebas
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
}

resource "aws_cloudwatch_log_group" "apigw_logs" {
  name              = "/aws/apigateway/access-logs"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.lambda_env_key.arn
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

  kms_key_arn = aws_kms_key.lambda_env_key.arn
  code_signing_config_arn = aws_lambda_code_signing_config.signing_config.arn
  reserved_concurrent_executions = 10
  vpc_config {
    subnet_ids         = data.aws_subnet_ids.default.ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
  mode = "Active"
  }


}

# ========== API Gateway ==========
resource "aws_apigatewayv2_api" "http_api" {
  name          = "iot-api"
  protocol_type = "HTTP"
}

# ========== Integración y Ruta para send_to_sqs ==========
resource "aws_apigatewayv2_integration" "send_to_sqs_integration" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.send_to_sqs.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "send_to_sqs_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /send_to_sqs"
  target    = "integrations/${aws_apigatewayv2_integration.send_to_sqs_integration.id}"
  authorization_type = "AWS_IAM"
}

resource "aws_lambda_permission" "allow_apigw_send_to_sqs" {
  statement_id  = "AllowExecutionFromAPIGatewaySendToSQS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.send_to_sqs.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}//"
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
  authorization_type = "AWS_IAM"

}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw_logs.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      ip                      = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      httpMethod              = "$context.httpMethod"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      protocol                = "$context.protocol"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }
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
  retention_in_days = 365
  kms_key_id       = aws_kms_key.lambda_env_key.arn
}

resource "aws_cloudwatch_log_group" "lambda_send_to_sqs_logs" {
  name              = "/aws/lambda/${aws_lambda_function.send_to_sqs.function_name}"
  retention_in_days = 365
  kms_key_id       = aws_kms_key.lambda_env_key.arn
  
}
resource "aws_sqs_queue" "lambda_dlq" {
  name = "lambda-dlq"
  sqs_managed_sse_enabled  = true
}
 
#MENSAJERIA
# SQS - Cola de mensaje
resource "aws_sqs_queue" "iot_alert_queue" {
  name                      = "iot_alert_queue"
  visibility_timeout_seconds = 30
  message_retention_seconds = 86400  # 1 día
  sqs_managed_sse_enabled   = true
}

#enviar a sqs
resource "aws_lambda_function" "send_to_sqs" {
  function_name    = "send_to_sqs"
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  filename         = "${path.module}/lambda_send_to_sqs.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda_send_to_sqs.zip")
  role             = aws_iam_role.lambda_role.arn

  environment {
    variables = {
      SQS_URL = aws_sqs_queue.iot_alert_queue.id
    }
  }

  tracing_config {
    mode = "Active"
  }

  reserved_concurrent_executions = 10

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  vpc_config {
    subnet_ids         = data.aws_subnet_ids.default.ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

# SNS - Topic de alertas
# ========================
resource "aws_sns_topic" "iot_alert_topic" {
  name = "iot_alert_topic"
  kms_master_key_id = aws_kms_key.lambda_env_key.arn
}

# ================================
# SNS - Suscripción por Correo
# ================================
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.iot_alert_topic.arn
  protocol  = "email"
  endpoint  = "spacherrest1@upao.edu.pe"  
}

resource "aws_lambda_function" "sqs_to_sns" {
  function_name = "sqs_to_sns"
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "${path.module}/lambda_sqs_to_sns.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda_sqs_to_sns.zip")
  role          = aws_iam_role.lambda_role.arn

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.iot_alert_topic.arn
    }
  }
  
  kms_key_arn = aws_kms_key.lambda_env_key.arn

  vpc_config {
    subnet_ids         = data.aws_subnet_ids.default.ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

# Trigger: SQS → Lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.iot_alert_queue.arn
  function_name    = aws_lambda_function.sqs_to_sns.arn
  batch_size       = 1
  enabled          = true
}
