output "cognito_user_pool_id" {
  description = "The ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.main_pool.id
}

output "cognito_user_pool_client_id" {
  description = "The ID of the Cognito User Pool Client (SPA)"
  value       = aws_cognito_user_pool_client.userpool_client.id
}

output "api_invoke_url" {
  description = "The URL to invoke the API Gateway dev stage"
  value       = "https://${aws_api_gateway_rest_api.rydes_api.id}.execute-api.ca-central-1.amazonaws.com/dev"
}

output "amplify_main_branch_url" {
  description = "The URL of the Amplify main branch"
  value       = "https://${aws_amplify_branch.main.branch_name}.${aws_amplify_app.rydes.default_domain}"
}