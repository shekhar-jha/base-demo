resource "aws_cloudwatch_log_group" "go_lambda" {
  name              = "/aws/lambda/${local.go_lambda_function_name}"
  retention_in_days = 14
}

data "aws_iam_policy_document" "go_lambda_cloudwatch_access" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
    effect    = "Allow"
  }
}
resource "aws_iam_policy" "go_lambda_cloudwatch_access" {
  name        = "${local.env_name_lower}_lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"
  policy      = data.aws_iam_policy_document.go_lambda_cloudwatch_access.json
}

resource "aws_iam_role_policy_attachment" "go_lambda_cloudwatch_access" {
  role       = aws_iam_role.go_function.name
  policy_arn = aws_iam_policy.go_lambda_cloudwatch_access.arn
}