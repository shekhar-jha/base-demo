##########################################
# Github repo information for reference
##########################################
data "github_repository" "base_demo_repo" {
  full_name = "${var.GITHUB_REPO.repo_owner}/${var.GITHUB_REPO.repo_name}"
}

##########################################
# Github repo environment definition
##########################################

resource "github_repository_environment" "base_demo_env" {
  repository  = data.github_repository.base_demo_repo.name
  environment = var.ENV_NAME
}

resource "github_actions_environment_secret" "base_demo_env_workload_idp" {
  repository      = data.github_repository.base_demo_repo.name
  environment     = github_repository_environment.base_demo_env.environment
  secret_name     = "GCP_Workload_IDP_Name"
  plaintext_value = google_iam_workload_identity_pool_provider.github_provider.name
}

resource "github_actions_environment_secret" "base_demo_env_service_account" {
  repository      = data.github_repository.base_demo_repo.name
  environment     = github_repository_environment.base_demo_env.environment
  secret_name     = "GCP_SERVICE_ACCT"
  plaintext_value = google_service_account.github_action_account.email
}

resource "github_actions_environment_secret" "base_demo_env_cloud_run_job" {
  repository      = data.github_repository.base_demo_repo.name
  environment     = github_repository_environment.base_demo_env.environment
  secret_name     = "GCP_CLOUD_RUN_JOB_NAME"
  plaintext_value = local.git_runner_build_name
}

resource "github_actions_environment_secret" "base_demo_env_region" {
  repository      = data.github_repository.base_demo_repo.name
  environment     = github_repository_environment.base_demo_env.environment
  secret_name     = "GCP_REGION"
  plaintext_value = local.current.region
}
