locals {
  github_runner_container_files = fileset("${path.module}/..", "github_runner/**")
}
resource "aws_codecommit_repository" "git_runner" {
  repository_name = "${var.ENV_NAME}_git_runner"
  description     = "Repository for git_runner infrastructure"
  default_branch  = "main"
  tags = {
    Name          = "${var.ENV_NAME} git_runner"
    Environment   = var.ENV_NAME
  }
  # Need to use put-file since create-commit results in file being uploaded in wrong format.
  # TODO: Identify how to handle uploading text files.
  provisioner "local-exec" {
    command       = <<-COMMIT
    source ${path.module}/../../../common/scripts/aws.sh
    source ${path.module}/../../../common/scripts/coderepo.sh
    CloudInit "${var.ENV_NAME}" "AWS" profile "${var.AWS_ENV_AUTH}" "e" 2
    CodeRepoInit "${var.ENV_NAME}" "AWS" ${aws_codecommit_repository.git_runner.repository_name}
    CodeRepoUpdate "${var.ENV_NAME}" "AWS" ${aws_codecommit_repository.git_runner.repository_name} "${path.module}/../github_runner"
    CodeRepoCommit "${var.ENV_NAME}" "AWS" ${aws_codecommit_repository.git_runner.repository_name}
    COMMIT
  }
}
resource "aws_iam_role_policy" "git_runner_code_commit" {
  name = "${var.ENV_NAME}_git_runner_code_commit_access"
  role        = aws_iam_role.git_runner.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Access to Code commit
      {
        "Action": [
          "codecommit:GitPull",
          "codecommit:Get*",
          "codecommit:BatchGetRepositories",
          "codecommit:List*"
        ],
        "Resource": ["arn:aws:codecommit:${data.aws_region.current.name}:*:${aws_codecommit_repository.git_runner.repository_name}"],
        "Effect": "Allow"
      },
    ]
  })
}

resource "aws_ecr_repository" "git_runner" {
  name = "${var.ENV_NAME}-git-runner"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    # TODO: Migrate to KMS
    encryption_type = "AES256"
  }
  tags = {
    Name               = "${var.ENV_NAME} git_runner"
    Environment        = var.ENV_NAME
  }
}

resource "aws_iam_role_policy" "git_runner_ecr" {
  name = "${var.ENV_NAME}_git_runner_code_ecr_access"
  role        = aws_iam_role.git_runner.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Access to Elastic Container Registry
      {
        "Effect": "Allow",
        "Action": "ecr:*",
        "Resource": "arn:aws:ecr:${data.aws_region.current.name}:*:repository/${aws_ecr_repository.git_runner.name}"
      },
      # Access to Elastic Container Registry Authorization Token
      {
        "Effect": "Allow",
        "Action": "ecr:GetAuthorizationToken",
        "Resource": "*"
      },
    ]
  })
}

