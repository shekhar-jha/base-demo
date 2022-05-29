terraform {
  backend "local" {}
  required_providers  {
    aws = {
      source = "hashicorp/aws"
    }
    github = {
      source = "integrations/github"
    }
  }
}

provider "aws" {
  region = var.AWS_ENV.region
  profile=var.AWS_ENV_AUTH
} 

provider "github" {
  # Assumes the GITHUB_TOKEN is set
  # for authentication
  owner = var.GITHUB_REPO.repo_owner
}