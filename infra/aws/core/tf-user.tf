locals {
   aws_iam_name   = "${local.env_name_lower}-infra-${random_string.ENV_SUFFIX.result}"
}

resource "aws_iam_user" "aws_user_tf_infra" {
  name = local.aws_iam_name
  tags = {
    Name        = "${var.ENV_NAME} Terraform Infra user"
    Environment = "${var.ENV_NAME}"
  }
}
resource "aws_iam_user_policy_attachment" "aws_user_tf_infra" {
  user       = aws_iam_user.aws_user_tf_infra.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_access_key" "aws_user_tf_infra" {
  user = aws_iam_user.aws_user_tf_infra.name
  pgp_key = data.local_sensitive_file.aws_tf_crypt.content_base64
}

output "aws_iam_user_arn" {
  value = aws_iam_user.aws_user_tf_infra.arn
}
output "aws_iam_user_access_key_id" {
  value = aws_iam_access_key.aws_user_tf_infra.id
}
output "aws_iam_user_access_key_secret" {
  value = aws_iam_access_key.aws_user_tf_infra.secret
  sensitive=true
}

output "aws_iam_user_access_key_secret_encrypt" {
  value = aws_iam_access_key.aws_user_tf_infra.encrypted_secret
}
