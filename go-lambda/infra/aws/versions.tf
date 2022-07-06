terraform {
  backend "local" {}
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region  = var.AWS_ENV_REGION
  profile = var.AWS_ENV_AUTH
}