##########################################
# SSL Certificate thumbprint for Github API
# for OpenID Connect Identity Provider
##########################################
data "external" "github-thumbprint" {
  program = ["bash", "./get-thumbprint.sh.tpl"]
}

##########################################
# AWS OpenID Connect provider for Github
##########################################
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.external.github-thumbprint.result.print]
  tags            = {
    Name        = "${var.ENV_NAME} Github OIDC Provider"
    Environment = "${var.ENV_NAME}"
  }
}

##########################################
# AWS IAM Role that can be assumed by
# Github actions from specific repo
##########################################
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

resource "aws_iam_role" "github_actions" {
  name               = "github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
  tags               = {
    Name        = "${var.ENV_NAME} Github Role"
    Environment = "${var.ENV_NAME}"
  }
}

##########################################
# Github actions from specific repo can
# perform the following operations
# 1. Run and stop tasks
# 2. Pass role to Task execution role.
##########################################
data "aws_iam_policy_document" "github_actions" {
  statement {
    actions   = ["ecs:RunTask"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "ecs:cluster"
      values   = [aws_ecs_cluster.git_runner.arn]
    }
  }
  statement {
    actions   = ["ecs:StopTask"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "ecs:cluster"
      values   = [aws_ecs_cluster.git_runner.arn]
    }
  }
  statement {
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.git_runner_ecs.arn]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "git_hub_actions_access"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions.json
}

##########################################
# Github repo information for reference
##########################################
data "github_repository" "base_demo_repo" {
  full_name = "${var.GITHUB_REPO.repo_owner}/${var.GITHUB_REPO.repo_name}"
}

##########################################
# Github repo environment definition
##########################################

resource "github_repository_environment" "base_demo_env" {
  repository  = data.github_repository.base_demo_repo.name
  environment = var.ENV_NAME
}

resource "github_actions_environment_secret" "base_demo_env_region" {
  repository      = data.github_repository.base_demo_repo.name
  environment     = github_repository_environment.base_demo_env.environment
  secret_name     = "AWS_REGION"
  plaintext_value = data.aws_region.current.name
}

resource "github_actions_environment_secret" "base_demo_env_role" {
  repository      = data.github_repository.base_demo_repo.name
  environment     = github_repository_environment.base_demo_env.environment
  secret_name     = "ROLE_TO_ASSUME"
  plaintext_value = aws_iam_role.github_actions.arn
}

resource "github_actions_environment_secret" "base_demo_env_security_group" {
  repository      = data.github_repository.base_demo_repo.name
  environment     = github_repository_environment.base_demo_env.environment
  secret_name     = "SECURITY_GROUP"
  plaintext_value = aws_security_group.git_runner.id
}

resource "github_actions_environment_secret" "base_demo_env_subnet" {
  repository      = data.github_repository.base_demo_repo.name
  environment     = github_repository_environment.base_demo_env.environment
  secret_name     = "SUBNET"
  plaintext_value = aws_subnet.public.id
}

