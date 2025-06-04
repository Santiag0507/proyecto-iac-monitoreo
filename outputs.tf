#output "lambda_function_name"  {
#   value = aws_lambda_function.iot_processor.function_name
#}

#output "dynamodb_table_name" {
 #  value = aws_dynamodb_table.iot_data.name
#}
#output "api_gateway_endpoint" {
 #  value = aws_apigatewayv2_api.http_api.api_endpoint
#}
#output "register_device_arn" {
 # value = aws_lambda_function.lambdas["register_device"].arn
#}
#output "lambda_register_device_arn" {
 # value = aws_lambda_function.lambdas["register_device"].arn
#}
#output "lambda_store_metrics_arn" {
 # value = aws_lambda_function.lambdas["store_metrics"].arn
#}
#output "lambda_alert_system_arn" {
 # value = aws_lambda_function.lambdas["alert_system"].arn
#}
#output "lambda_get_dashboard_arn" {
 # value = aws_lambda_function.lambdas["get_dashboard"].arn
#}
#output "lambda_generate_report_arn" {
 # value = aws_lambda_function.lambdas["generate_report"].arn
#}
# 🔗 URL de acceso a la API
output "api_gateway_endpoint" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}

# 🗃️ Nombre de la tabla DynamoDB
output "dynamodb_table_name" {
  value = aws_dynamodb_table.iot_data.name
}

# ⚙️ Funciones Lambda (ARNs)
output "lambda_register_device_arn" {
  value = aws_lambda_function.lambdas["register_device"].arn
}

output "lambda_store_metrics_arn" {
  value = aws_lambda_function.lambdas["store_metrics"].arn
}

output "lambda_alert_system_arn" {
  value = aws_lambda_function.lambdas["alert_system"].arn
}

output "lambda_get_dashboard_arn" {
  value = aws_lambda_function.lambdas["get_dashboard"].arn
}

output "lambda_generate_report_arn" {
  value = aws_lambda_function.lambdas["generate_report"].arn
}
