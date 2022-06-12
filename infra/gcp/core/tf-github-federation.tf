# Activate service
resource "google_project_service" "resourcemanager" {
  project = local.current.project
  service = "cloudresourcemanager.googleapis.com"

  disable_on_destroy = false
}
resource "google_project_service" "iamcredentials" {
  project = local.current.project
  service = "iamcredentials.googleapis.com"

  disable_on_destroy = false
}
resource "google_project_service" "sts" {
  project = local.current.project
  service = "sts.googleapis.com"

  disable_on_destroy = false
}

##############################################
# Service account used by Github to run job
##############################################
resource "google_service_account" "github_action_account" {
  account_id   = "${local.git_runner_build_name}-gh-action"
  display_name = "Github account"
  description  = "Service Account for Github to invoke operation"
  project      = local.current.project
}


##########################################
# Google Identity pool for Github
##########################################
resource "google_iam_workload_identity_pool" "git_runner" {
  provider                  = google-beta
  workload_identity_pool_id = local.git_runner_build_name
  display_name              = "${var.ENV_NAME}-gh-id-pool"
  description               = "Github identity pool for ${var.ENV_NAME}"
  depends_on                = [
    google_project_service.iam, google_project_service.resourcemanager,
    google_project_service.sts, google_project_service.iamcredentials
  ]
}

##########################################
# Google Identity pool for Github
##########################################
resource "google_iam_workload_identity_pool_provider" "github_provider" {
  provider                           = google-beta
  display_name                       = "${var.ENV_NAME}-gh-id-provider"
  description                        = "Github Identity pool provider for ${var.ENV_NAME}"
  workload_identity_pool_id          = google_iam_workload_identity_pool.git_runner.workload_identity_pool_id
  workload_identity_pool_provider_id = local.git_runner_build_name
  attribute_mapping                  = {
    "google.subject"       = "assertion.sub"
    "attribute.aud"        = "assertion.aud"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }
  oidc {
    issuer_uri        = "https://token.actions.githubusercontent.com"
    allowed_audiences = []
  }
}

##########################################
# IAM Service account mapping for Github
##########################################
resource "google_service_account_iam_member" "github_action_access" {
  provider           = google-beta
  service_account_id = google_service_account.github_action_account.id
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.git_runner.name}/attribute.repository/${var.GITHUB_REPO.repo_owner}/${var.GITHUB_REPO.repo_name}"
}