output "lambda_function_name"  {
   value = aws_lambda_function.iot_processor.function_name
}

output "dynamodb_table_name" {
   value = aws_dynamodb_table.iot_data.name
}

output "api_gateway_endpoint" {
   value = aws_apigatewayv2_api.http_api.api_endpoint
}
