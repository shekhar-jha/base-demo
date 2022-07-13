terraform {
  backend "local" {}
  required_providers {
    google = {
      source = "hashicorp/google"
    }
    google-beta = {
      source = "hashicorp/google-beta"
    }
  }
}

provider "google" {
  # Assumes the Application default authentication
  # has already been performed.
  region  = var.GCP_REGION
  project = var.GCP_PROJECT
}

provider "google-beta" {
  # Assumes the Application default authentication
  # has already been performed.
  region  = var.GCP_REGION
  project = var.GCP_PROJECT
}
