resource "aws_amplify_app" "rydes" {
  name       = "rydes"
  repository = "https://github.com/devmarye/rydes"
  access_token = var.github_token

   # Build spec for website in subfolder
 build_spec = <<-EOT
version: 1
frontend:
  phases:
    preBuild:
      commands: []
    build:
      commands: []
    cache:
      paths: []
  artifacts:
    baseDirectory: website
    files:  
      - '**/*'
  
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
