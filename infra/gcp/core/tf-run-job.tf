##############################################
# Service account to run job
##############################################
resource "google_service_account" "git_runner_job_runner" {
  account_id   = "${local.git_runner_build_name}-job"
  display_name = "Git runner job executor"
  description  = "Service Account for Git Runner job execution"
  project      = local.current.project
}


##############################################
# Github PAT secret must be created before running this script.
##############################################
data "google_secret_manager_secret_version" "github_pat" {
  secret = local.github_pat_name
}

##############################################
# Access to github PAT
##############################################
resource "google_secret_manager_secret_iam_member" "github_pat" {
  secret_id = data.google_secret_manager_secret_version.github_pat.name
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.git_runner_job_runner.email}"
}

##############################################
# Get current state of image build and job
# creation
##############################################
data "external" "git_runner_job" {
  program    = ["bash", "./check-job.sh.tpl", local.git_runner_artifactory_url, local.git_runner_build_name]
  depends_on = [google_artifact_registry_repository.git_runner_image_repo]
}

##############################################
# Trigger to build Github image
##############################################
resource "null_resource" "git_runner_image" {
  provisioner "local-exec" {
    command = <<-TRIGGER_BUILD
    if [[ "${data.external.git_runner_job.result.image}" == "" ]]; then
      gcloud beta builds triggers run ${local.git_runner_build_name} --branch=main
    fi
    TRIGGER_BUILD
  }
  depends_on = [
    null_resource.commit_git_runner, data.external.git_runner_job
  ]
}

##############################################
# Create Cloud run job for execution.
##############################################
resource "null_resource" "git_runner_job" {
  triggers = {
    image_exists = data.external.git_runner_job.result.image == ""?"false" : "true"
    job_name     = local.git_runner_build_name
  }
  provisioner "local-exec" {
    command = <<-JOB_CREATED
    if [[ "${data.external.git_runner_job.result.image}" != "" ]]; then
      gcloud beta run jobs create ${local.git_runner_build_name} --image \
         "${local.git_runner_artifactory_url}/git_runner:latest" \
         --binary-authorization=default --service-account="${google_service_account.git_runner_job_runner.email}" \
         --set-env-vars=ENV_NAME=${local.env_name_lower},RUNNER_NAME=${local.env_name_lower}-gcp-git_runner,GITHUB_OWNER=${var.GITHUB_REPO.repo_owner},GITHUB_REPOSITORY=${var.GITHUB_REPO.repo_name}  \
         --set-secrets=GITHUB_PAT=${local.github_pat_name}:latest \
         --async
    else
      echo "Image git_runner is not available yet. Please try after some time."
      exit 1
    fi
    JOB_CREATED
  }
  provisioner "local-exec" {
    when    = destroy
    command = <<-JOB_DELETED
    gcloud beta run jobs delete ${self.triggers.job_name}
    JOB_DELETED
  }
  depends_on = [
    null_resource.commit_git_runner, google_secret_manager_secret_iam_member.github_pat,
    google_project_service.cloudrun, google_project_service.cloudrun-authz
  ]
}

# Activate service
resource "google_project_service" "cloudrun" {
  project            = local.current.project
  service            = "run.googleapis.com"
  disable_on_destroy = false
}
# Activate service
resource "google_project_service" "cloudrun-authz" {
  project            = local.current.project
  service            = "binaryauthorization.googleapis.com"
  disable_on_destroy = false
}
