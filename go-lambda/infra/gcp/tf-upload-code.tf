locals {
  go_code_dir           = "../../cmd"
  go_docker_dir         = "${path.module}/../gcp/docker"
  code_directory_exists = fileexists("${local.go_code_dir}/go.mod")
  goCode_sum            = join("", [for f in fileset(local.go_code_dir, "*.go") : filesha1("${local.go_code_dir}/${f}")])
  dockerCode_sum        = join("", [for f in fileset(local.go_docker_dir, "*") : filesha1("${local.go_docker_dir}/${f}")])
  sourcecode_hash       = sha1(join("", [local.goCode_sum, local.dockerCode_sum]))
}

##############################################
# Upload Docker and Cloud Run Go code
##############################################
resource "null_resource" "commit_cloudRun_go" {
  count    = 0 //local.code_directory_exists?1 : 0
  triggers = {
    dir_sha = local.sourcecode_hash
  }
  provisioner "local-exec" {
    command = <<-COMMIT
    source ${path.module}/../common/scripts/cloud.sh
    source ${path.module}/../common/scripts/coderepo.sh
    CloudInit "${var.ENV_NAME}" "GCP" 'adc' '' 'e' 1
    CodeRepoInit "${var.ENV_NAME}" "GCP" ${google_sourcerepo_repository.cloudRun_go.name}
    CodeRepoUpdate "${var.ENV_NAME}" "GCP" ${google_sourcerepo_repository.cloudRun_go.name} "${local.go_code_dir}"
    CodeRepoUpdate "${var.ENV_NAME}" "GCP" ${google_sourcerepo_repository.cloudRun_go.name} "${local.go_docker_dir}/"
    CodeRepoCommit "${var.ENV_NAME}" "GCP" ${google_sourcerepo_repository.cloudRun_go.name}
    COMMIT
  }
  depends_on = [google_cloudbuild_trigger.cloudRun_go_image_builder]
}

##############################################
# Build Cloud Run Go image and publish
##############################################
resource "null_resource" "build_cloudRun_go" {
  count    = local.code_directory_exists?1 : 0
  triggers = {
    dir_sha = local.sourcecode_hash
  }
  provisioner "local-exec" {
    command = <<-BUILD
    gcloud auth configure-docker "${local.cloudRun_go_repo}" --quiet
    export BUILD_DIR_NAME="${var.ENV_NAME}-docker-build"
    echo "Building docker image in $BUILD_DIR_NAME"
    mkdir "$BUILD_DIR_NAME"
    cp -R "${local.go_code_dir}" "$BUILD_DIR_NAME"
    cp -R "${local.go_docker_dir}/" "$BUILD_DIR_NAME"
    docker build -t "${local.cloudRun_go_artifactory_url}/cloudrun_go" "$BUILD_DIR_NAME" --quiet
    docker push "${local.cloudRun_go_artifactory_url}/cloudrun_go"
    BUILD
  }
  depends_on = [google_artifact_registry_repository_iam_member.cloudRun_go_user_artifact_access]
}

# Access to docker image repository by current user
resource "google_artifact_registry_repository_iam_member" "cloudRun_go_user_artifact_access" {
  provider   = google-beta
  project    = google_artifact_registry_repository.cloudRun_go_image_repo.project
  location   = google_artifact_registry_repository.cloudRun_go_image_repo.location
  repository = google_artifact_registry_repository.cloudRun_go_image_repo.name
  role       = "roles/artifactregistry.writer"
  member     = var.GCP_ID
}