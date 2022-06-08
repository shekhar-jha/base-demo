resource "random_string" "ENV_SUFFIX" {
  length  = 4
  upper   = false
  lower   = true
  numeric = true
  special = false
}

locals {
  env_name_lower = lower(var.ENV_NAME)
}

data "google_client_config" "current" {
  lifecycle {
    postcondition {
      condition     = self.region != ""
      error_message = "region attribute must be set. Please set the region in the provider configuration"
    }
    postcondition {
      condition     = self.project != ""
      error_message = "project attribute must be set. Please set the project in the provider configuration"
    }
  }
}
