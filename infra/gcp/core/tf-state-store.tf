locals {
  gcp_gcs_tf_state_bucket = "${local.env_name_lower}-tf-state-${random_string.ENV_SUFFIX.result}"
}

resource "google_storage_bucket" "gcp_gcs_tf_state" {
  name     = local.gcp_gcs_tf_state_bucket
  location = data.google_client_config.current.region
  project  = data.google_client_config.current.project
  versioning {
    enabled = true
  }
  force_destroy = true
  labels        = {
    name        = "${var.ENV_NAME}-terraform-state-bucket"
    environment = local.env_name_lower
  }
}

output "STATE_BUCKET_ID" {
  value = split("/", google_storage_bucket.gcp_gcs_tf_state.url)[2]
}
