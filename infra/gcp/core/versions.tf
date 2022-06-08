terraform {
  backend "local" {}
  required_providers {
    google = {
      source = "hashicorp/google"
    }
    github = {
      source = "integrations/github"
    }
  }
}

provider "google" {
  # Assumes the Application default authentication
  # has already been performed.
  region  = var.GCP_REGION
  project = var.GCP_PROJECT
}

provider "github" {
  # Assumes the GITHUB_TOKEN is set
  # for authentication
  owner = var.GITHUB_REPO.repo_owner
}