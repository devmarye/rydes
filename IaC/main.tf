resource "aws_amplify_app" "rydes" {
  name        = "rydes"
  repository  = "https://github.com/devmarye/rydes"
  access_token = var.github_token

  build_spec = <<-EOT
version: 1

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
