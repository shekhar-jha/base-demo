resource "random_string" "ENV_SUFFIX" {
  length  = 4
  upper   = false
  lower   = true
  number  = true
  special = false
}
locals {
  env_name_lower = lower(var.ENV_NAME)
}
