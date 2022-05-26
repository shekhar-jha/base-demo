
data "external" "github-thumbprint" {
  program = ["bash", "./get-thumbprint.sh.tpl"]
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.external.github-thumbprint.result.print]
  tags = {
    Name = "${var.ENV_NAME} Github OIDC Provider"
    Environment = "${var.ENV_NAME}"
  }
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [
        "repo:${var.GITHUB_REPO.repo_owner}/${var.GITHUB_REPO.repo_name}:*"
      ]
    }
  }
}



