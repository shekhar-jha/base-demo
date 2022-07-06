locals {
  go_lambda_function_name  = "${local.env_name_lower}_go_lambda_${local.env_suffix}"
  go_lambda_zip_exists     = fileexists(local.go_lambda_zip_path)
  go_lambda_handler_name   = "lambdaMain"
  go_lambda_qualifier_name = "dev"
}

data "aws_iam_policy_document" "go_function_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
    effect = "Allow"
  }
}

resource "aws_iam_role" "go_function" {
  name               = "${local.env_name_lower}_go_lambda_${local.env_suffix}"
  assume_role_policy = data.aws_iam_policy_document.go_function_policy.json
}

resource "aws_lambda_function" "go_function" {
  description   = "Go function for demo"
  function_name = local.go_lambda_function_name
  role          = aws_iam_role.go_function.arn
  handler       = local.go_lambda_handler_name
  runtime       = "go1.x"
  architectures = ["x86_64"]
  environment {
    variables = {
      "ENV1" : "VAL1"
    }
  }
  ephemeral_storage {
    size = 512
  }
  memory_size                    = 128
  timeout                        = 300
  package_type                   = "Zip"
  filename                       = local.go_lambda_zip_path
  source_code_hash               = local.sourcecode_hash
  publish                        = false
  reserved_concurrent_executions = -1
  tags                           = { "ENV" : var.ENV_NAME }
  depends_on                     = [
    null_resource.build_go, aws_iam_role_policy_attachment.go_lambda_cloudwatch_access,
    aws_cloudwatch_log_group.go_lambda
  ]
}


resource "aws_lambda_alias" "go_function_dev" {
  name             = local.go_lambda_qualifier_name
  description      = "${var.ENV_NAME} Go Lambda Development version"
  function_name    = aws_lambda_function.go_function.function_name
  function_version = "$LATEST"
}

resource "aws_lambda_function_event_invoke_config" "go_function_dev" {
  function_name                = aws_lambda_function.go_function.function_name
  qualifier                    = aws_lambda_alias.go_function_dev.name
  maximum_event_age_in_seconds = 60
  maximum_retry_attempts       = 0
}

resource "aws_lambda_function_url" "go_function_dev" {
  function_name      = aws_lambda_function.go_function.function_name
  authorization_type = "NONE"
  qualifier          = aws_lambda_alias.go_function_dev.name
}

resource "aws_lambda_invocation" "go_function_dev" {
  function_name = aws_lambda_function.go_function.function_name
  triggers      = { redeployment = local.sourcecode_hash }
  input         = jsonencode({
    Name = "John Doe"
  })
  depends_on = [null_resource.build_go, aws_lambda_function.go_function]
}

output "AWS_LAMBDA_URL" {
  value = aws_lambda_function_url.go_function_dev.function_url
}

output "AWS_TEST_RESULT" {
  value = aws_lambda_invocation.go_function_dev
}