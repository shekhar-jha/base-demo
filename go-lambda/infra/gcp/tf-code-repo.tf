locals {
  cloudRun_go_build_name      = "${local.env_name_lower}-cloudrun-go-${random_string.ENV_SUFFIX.result}"
  cloudRun_go_repo = "${local.current.region}-docker.pkg.dev"
  cloudRun_go_artifactory_url = "${local.cloudRun_go_repo}/${local.current.project}/${local.cloudRun_go_build_name}"
}

##############################################
# Source code git repository
##############################################
resource "google_sourcerepo_repository" "cloudRun_go" {
  name       = local.cloudRun_go_build_name
  project    = local.current.project
  depends_on = [google_project_service.source_repo]
}

# Activate service
resource "google_project_service" "source_repo" {
  project            = local.current.project
  service            = "sourcerepo.googleapis.com"
  disable_on_destroy = false
}

# Access to source code git repository
resource "google_sourcerepo_repository_iam_member" "cloudRun_go_user_src_repo_access" {
  project    = google_sourcerepo_repository.cloudRun_go.project
  repository = google_sourcerepo_repository.cloudRun_go.name
  role       = "roles/source.writer"
  member     = var.GCP_ID
}

##############################################
# Docker Image repository
##############################################
resource "google_artifact_registry_repository" "cloudRun_go_image_repo" {
  provider      = google-beta
  repository_id = local.cloudRun_go_build_name
  format        = "DOCKER"
  location      = local.current.region
  project       = local.current.project
  description   = "Cloud Run Go image repository"
  depends_on    = [google_project_service.artifact]
}

# Activate service
resource "google_project_service" "artifact" {
  project            = local.current.project
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}