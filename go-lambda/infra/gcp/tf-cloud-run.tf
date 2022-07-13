resource "google_cloud_run_service" "cloudRun_go_run_service" {
  name     = local.cloudRun_go_build_name
  location = local.current.region
  template {
    spec {
      containers {
        image = "${local.cloudRun_go_artifactory_url}/cloudrun_go"
      }
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }
  depends_on = [google_project_service.cloud_run, null_resource.build_cloudRun_go]
}

data "google_iam_policy" "noAuth_policy" {
  binding {
    role    = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "cloudRun_go_run_service_no_auth" {
  location = google_cloud_run_service.cloudRun_go_run_service.location
  project  = google_cloud_run_service.cloudRun_go_run_service.project
  service  = google_cloud_run_service.cloudRun_go_run_service.name

  policy_data = data.google_iam_policy.noAuth_policy.policy_data
}

# Activate service
resource "google_project_service" "cloud_run" {
  project            = local.current.project
  service            = "run.googleapis.com"
  disable_on_destroy = false
}


output "CLOUD_RUN_URL" {
  value = google_cloud_run_service.cloudRun_go_run_service.status
}