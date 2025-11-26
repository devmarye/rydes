resource "aws_amplify_app" "rydes" {
  name        = "rydes"
  repository  = "https://github.com/devmarye/rydes"
  access_token = var.github_token

  build_spec = <<-EOT
version: 1
frontend:
  phases:
    preBuild:
      commands: []
    build:
      commands: []
  artifacts:
    baseDirectory: website
    files:
      - '**/*'
  cache:
    paths: []
EOT

  environment_variables = {
    ENV = "prod"
  }
}



resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.rydes.id
  branch_name = "main"
  enable_auto_build = true
}

resource "aws_cognito_user_pool" "main_pool" {
  name = "rydes_pool"

  
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_uppercase = true
    require_symbols   = true
  }


  mfa_configuration = "OFF" 

  account_recovery_setting {
    recovery_mechanism {
      name = "verified_email"
      priority = 1
    }
  }

}

resource "aws_cognito_user_pool_client" "userpool_client" {
  name                                = "rydes-client"
  user_pool_id                        = aws_cognito_user_pool.main_pool.id
  generate_secret                     = false               
  allowed_oauth_flows                 = ["code"]            
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                = ["openid", "email", "profile"]

  callback_urls = [
    "https://<your-amplify-domain>.amplifyapp.com/callback", 
  ]
  logout_urls = [
    "https://<your-amplify-domain>.amplifyapp.com/logout",    
  ]

  supported_identity_providers = ["COGNITO"]

  prevent_user_existence_errors = "ENABLED"
}

resource "aws_cognito_user_pool_domain" "default_domain" {
  domain       = "rydes-spa-demo" 
  user_pool_id = aws_cognito_user_pool.main_pool.id
}