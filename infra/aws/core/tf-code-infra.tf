locals {
  github_runner_container_files = fileset("${path.module}/..", "github_runner/**")
}
resource "aws_codecommit_repository" "git_runner" {
  repository_name = "git_runner"
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
    COMMIT_ID=$(aws codecommit put-file  --region ${var.AWS_ENV.region} --profile '${var.AWS_ENV_AUTH}' \
      --repository-name ${aws_codecommit_repository.git_runner.repository_name} --branch-name main \
      --commit-message 'Change updates' --file-path "github_runner/Dockerfile"  \
      --file-content "fileb://${path.module}/../github_runner/Dockerfile" \
      --output text --query "commitId")
    COMMIT_ID=$(aws codecommit put-file  --region ${var.AWS_ENV.region} --profile '${var.AWS_ENV_AUTH}' \
      --repository-name ${aws_codecommit_repository.git_runner.repository_name} --branch-name main \
      --commit-message 'Change updates' --file-path "github_runner/build-runner.sh"  \
      --file-content "fileb://${path.module}/../github_runner/build-runner.sh" \
      --output text --parent-commit-id $${COMMIT_ID} --query "commitId")
    COMMIT_ID=$(aws codecommit put-file  --region ${var.AWS_ENV.region} --profile '${var.AWS_ENV_AUTH}' \
      --repository-name ${aws_codecommit_repository.git_runner.repository_name} --branch-name main \
      --commit-message 'Change updates' --file-path "github_runner/entrypoint.sh"  \
      --file-content "fileb://${path.module}/../github_runner/entrypoint.sh" \
      --output text --parent-commit-id $${COMMIT_ID} --query "commitId")
    COMMIT
  }
}

resource "aws_ecr_repository" "git_runner" {
  name = "git_runner"
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

