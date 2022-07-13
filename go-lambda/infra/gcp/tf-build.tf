##############################################
# Service account to build and publish image
##############################################
#resource "google_service_account" "cloudRun_go_image_build" {
#  account_id   = local.cloudRun_go_build_name
#  display_name = "Go Cloud Run image builder"
#  description  = "Service Account for Go Cloud Run Image build"
#  project      = local.current.project
#}

## Access to source code git repository
#resource "google_sourcerepo_repository_iam_member" "cloudRun_go_image_builder_src_repo_access" {
#  project    = google_sourcerepo_repository.cloudRun_go.project
#  repository = google_sourcerepo_repository.cloudRun_go.name
#  role       = "roles/source.reader"
#  member     = "serviceAccount:${google_service_account.cloudRun_go_image_build.email}"
#}
#
## Access to docker image repository
#resource "google_artifact_registry_repository_iam_member" "cloudRun_go_image_builder_artifact_access" {
#  provider   = google-beta
#  project    = google_artifact_registry_repository.cloudRun_go_image_repo.project
#  location   = google_artifact_registry_repository.cloudRun_go_image_repo.location
#  repository = google_artifact_registry_repository.cloudRun_go_image_repo.name
#  role       = "roles/artifactregistry.writer"
#  member     = "serviceAccount:${google_service_account.cloudRun_go_image_build.email}"
#}

##############################################
# Build trigger
##############################################
resource "google_cloudbuild_trigger" "cloudRun_go_image_builder" {
  name = local.cloudRun_go_build_name
  trigger_template {
    branch_name = "main"
    repo_name   = google_sourcerepo_repository.cloudRun_go.name
    project_id  = data.google_client_config.current.project
  }
#  service_account = google_service_account.cloudRun_go_image_build.id
  build {
    source {
      repo_source {
        repo_name   = google_sourcerepo_repository.cloudRun_go.name
        branch_name = "main"
      }
    }
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "build", "-t",
        "${local.cloudRun_go_artifactory_url}/cloudrun_go",
        "."
      ]
    }
    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
    images = [
      "${local.cloudRun_go_artifactory_url}/cloudrun_go"
    ]
  }
  depends_on = [google_project_service.cloud_build]
#, google_project_service.iam]
}

# Activate service
resource "google_project_service" "cloud_build" {
  project            = local.current.project
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

# Activate service
#resource "google_project_service" "iam" {
#  project            = local.current.project
#  service            = "iam.googleapis.com"
#  disable_on_destroy = false
#}

##############################################
# Access setup for build trigger
# https://cloud.google.com/build/docs/securing-builds/configure-user-specified-service-accounts#permissions
##############################################
#resource "google_service_account_iam_member" "git_runner_build_trigger_current_user" {
#  service_account_id = google_service_account.cloudRun_go_image_build.name
#  role               = "roles/iam.serviceAccountUser"
#  member             = var.GCP_ID
#}

