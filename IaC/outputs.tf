output "cognito_user_pool_id" {
  description = "The ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.main_pool.id
}

output "cognito_user_pool_client_id" {
  description = "The ID of the Cognito User Pool Client (SPA)"
  value       = aws_cognito_user_pool_client.userpool_client.id
}