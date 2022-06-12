locals {
  git_runner_build_name      = "${local.env_name_lower}-git-runner-${random_string.ENV_SUFFIX.result}"
  git_runner_artifactory_url = "${local.current.region}-docker.pkg.dev/${local.current.project}/${local.git_runner_build_name}"
  github_pat_name            = "github_pat-${var.GITHUB_REPO.repo_owner}-${var.GITHUB_REPO.repo_name}"
}


##############################################
# Service account to build and publish image
##############################################
resource "google_service_account" "git_runner_image_build" {
  account_id   = local.git_runner_build_name
  display_name = "Git runner image builder"
  description  = "Service Account for Git Runner Image build"
  project      = local.current.project
}

##############################################
# Storage bucket for build logs
##############################################
resource "google_storage_bucket" "git_runner_build_logs" {
  name     = local.git_runner_build_name
  location = local.current.region
  project  = local.current.project
  versioning {
    enabled = true
  }
  force_destroy = true
  labels        = {
    name        = "${var.ENV_NAME}-git-runner-build-logs"
    environment = local.env_name_lower
  }
}

##############################################
# Access to build logs
##############################################
resource "google_storage_bucket_iam_member" "git_runner_image_builder_log_store_access" {
  bucket = google_storage_bucket.git_runner_build_logs.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.git_runner_image_build.email}"
}


##############################################
# Source code git repository
##############################################
resource "google_sourcerepo_repository" "git_runner" {
  name       = local.git_runner_build_name
  project    = local.current.project
  depends_on = [google_project_service.source_repo]
}

# Activate service
resource "google_project_service" "source_repo" {
  project            = local.current.project
  service            = "sourcerepo.googleapis.com"
  disable_on_destroy = false
}

##############################################
# Access to source code git repository
##############################################
resource "google_sourcerepo_repository_iam_member" "git_runner_image_builder_src_repo_access" {
  project    = google_sourcerepo_repository.git_runner.project
  repository = google_sourcerepo_repository.git_runner.name
  role       = "roles/source.reader"
  member     = "serviceAccount:${google_service_account.git_runner_image_build.email}"
}

##############################################
# github_runner Docker file upload
##############################################
resource "null_resource" "commit_git_runner" {
  provisioner "local-exec" {
    command = <<-COMMIT
    source ${path.module}/../../../common/scripts/gcp.sh
    source ${path.module}/../../../common/scripts/coderepo.sh
    CloudInit "${var.ENV_NAME}" "GCP" adc "" "e" 2
    CodeRepoInit "${var.ENV_NAME}" "GCP" ${google_sourcerepo_repository.git_runner.name}
    CodeRepoUpdate "${var.ENV_NAME}" "GCP" ${google_sourcerepo_repository.git_runner.name} "${path.module}/../github_runner"
    CodeRepoCommit "${var.ENV_NAME}" "GCP" ${google_sourcerepo_repository.git_runner.name}
    COMMIT
  }
  depends_on = [google_cloudbuild_trigger.git_runner_image_builder]
}

##############################################
# Build trigger
##############################################
resource "google_cloudbuild_trigger" "git_runner_image_builder" {
  name = local.git_runner_build_name
  trigger_template {
    branch_name = "main"
    repo_name   = google_sourcerepo_repository.git_runner.name
    project_id  = data.google_client_config.current.project
  }
  service_account = google_service_account.git_runner_image_build.id
  build {
    logs_bucket = google_storage_bucket.git_runner_build_logs.name
    source {
      repo_source {
        repo_name   = google_sourcerepo_repository.git_runner.name
        branch_name = "main"
      }
    }
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "build", "-t",
        "${local.git_runner_artifactory_url}/git_runner",
        "./github_runner"
      ]
    }
    images = [
      "${local.git_runner_artifactory_url}/git_runner"
    ]
  }
  depends_on = [google_project_service.cloud_build, google_project_service.iam]
}

# Activate service
resource "google_project_service" "cloud_build" {
  project            = local.current.project
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

# Activate service
resource "google_project_service" "iam" {
  project            = local.current.project
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

##############################################
# Access setup for build trigger
# https://cloud.google.com/build/docs/securing-builds/configure-user-specified-service-accounts#permissions
##############################################
resource "google_service_account_iam_member" "git_runner_build_trigger_current_user" {
  service_account_id = google_service_account.git_runner_image_build.name
  role               = "roles/iam.serviceAccountUser"
  member             = var.GCP_ID
}

#resource "google_project_iam_member" "git_runner_image_builder_log_write" {
#  project = data.google_client_config.current.project
#  role    = "roles/logging.logWriter"
#  member  = "serviceAccount:${google_service_account.git_runner_image_build.email}"
#}

##############################################
# Docker Image repository
##############################################
resource "google_artifact_registry_repository" "git_runner_image_repo" {
  provider      = google-beta
  repository_id = local.git_runner_build_name
  format        = "DOCKER"
  location      = local.current.region
  project       = local.current.project
  description   = "Github runner image repository"
  depends_on    = [google_project_service.artifact]
}

# Activate service
resource "google_project_service" "artifact" {
  project            = local.current.project
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

##############################################
# Access to docker image repository
##############################################
resource "google_artifact_registry_repository_iam_member" "git_runner_image_builder_artifact_access" {
  provider   = google-beta
  project    = google_artifact_registry_repository.git_runner_image_repo.project
  location   = google_artifact_registry_repository.git_runner_image_repo.location
  repository = google_artifact_registry_repository.git_runner_image_repo.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.git_runner_image_build.email}"
}

