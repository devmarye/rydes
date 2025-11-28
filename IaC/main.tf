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

resource "aws_dynamodb_table" "rydes_table" {
  name           = "rydes_table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "RideId"

  attribute {
    name = "RideId"
    type = "S"
  }

}

resource "aws_iam_role" "lambda_role" {
  name = "rydes-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "rydes-lambda-dynamodb-policy"
  description = "Allows Lambda to write to DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = aws_dynamodb_table.rydes_table.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "requestRydes_code" {
  type        = "zip"
  source_file = "${path.module}/lambda/requestRydes.mjs"
  output_path = "${path.module}/lambda/requestRydes.zip"
}

resource "aws_lambda_function" "myfunc" {
  filename         = data.archive_file.requestRydes_code.output_path
  source_code_hash = data.archive_file.requestRydes_code.output_base64sha256
  function_name    = "requestRydes"
  role             = aws_iam_role.lambda_role.arn
  handler          =  "requestRydes.handler"
  runtime          = "nodejs18.x"
  
  depends_on = [
    aws_iam_role_policy_attachment.lambda_policy_attach,
    aws_iam_role_policy_attachment.lambda_basic_execution
  ]
}

resource "aws_api_gateway_rest_api" "rydes_api" {
  name        = "rydes-api"
  description = "API for requesting rides"
}

resource "aws_api_gateway_resource" "rides_resource" {
  rest_api_id = aws_api_gateway_rest_api.rydes_api.id
  parent_id   = aws_api_gateway_rest_api.rydes_api.root_resource_id
  path_part   = "ride"
}

resource "aws_api_gateway_authorizer" "cognito_auth" {
  name                   = "cognito-authorizer"
  rest_api_id            = aws_api_gateway_rest_api.rydes_api.id
  type                   = "COGNITO_USER_POOLS"
  provider_arns          = [aws_cognito_user_pool.main_pool.arn]
  identity_source        = "method.request.header.Authorization"
}

resource "aws_api_gateway_method" "post_rides" {
  rest_api_id   = aws_api_gateway_rest_api.rydes_api.id
  resource_id   = aws_api_gateway_resource.rides_resource.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_auth.id
}

resource "aws_api_gateway_integration" "rides_post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rydes_api.id
  resource_id             = aws_api_gateway_resource.rides_resource.id
  http_method             = aws_api_gateway_method.post_rides.http_method

  integration_http_method = "POST"      
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.myfunc.invoke_arn
}

resource "aws_lambda_permission" "allow_apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.myfunc.arn
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.rydes_api.execution_arn}/*/*"
}

resource "aws_api_gateway_method" "options_rides" {
  rest_api_id = aws_api_gateway_rest_api.rydes_api.id
  resource_id = aws_api_gateway_resource.rides_resource.id
  http_method = "OPTIONS"
  authorization = "NONE"
}
resource "aws_api_gateway_method_response" "options_rides_response" {
  rest_api_id = aws_api_gateway_rest_api.rydes_api.id
  resource_id = aws_api_gateway_resource.rides_resource.id
  http_method = "OPTIONS"
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "options_rides_integration" {
  rest_api_id = aws_api_gateway_rest_api.rydes_api.id
  resource_id = aws_api_gateway_resource.rides_resource.id
  http_method = aws_api_gateway_method.options_rides.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration_response" "options_rides_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.rydes_api.id
  resource_id = aws_api_gateway_resource.rides_resource.id
  http_method = aws_api_gateway_method.options_rides.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_method_response.options_rides_response]

  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_method_response" "post_rides_response" {
  rest_api_id = aws_api_gateway_rest_api.rydes_api.id
  resource_id = aws_api_gateway_resource.rides_resource.id
  http_method = aws_api_gateway_method.post_rides.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}


resource "aws_api_gateway_integration_response" "post_rides_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.rydes_api.id
  resource_id = aws_api_gateway_resource.rides_resource.id
  http_method = aws_api_gateway_method.post_rides.http_method
  status_code = aws_api_gateway_method_response.post_rides_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [aws_api_gateway_method_response.post_rides_response]
}


resource "aws_api_gateway_deployment" "rydes_deployment" {
  depends_on = [
    aws_api_gateway_integration.rides_post_integration,
    aws_api_gateway_integration.options_rides_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.rydes_api.id
}

resource "aws_api_gateway_stage" "dev_stage" {
  deployment_id = aws_api_gateway_deployment.rydes_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.rydes_api.id
  stage_name    = "dev"
}

output "api_invoke_url" {
  value = "https://${aws_api_gateway_rest_api.rydes_api.id}.execute-api.ca-central-1.amazonaws.com/dev"
}
