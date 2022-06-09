resource "random_string" "ENV_SUFFIX" {
  length  = 4
  upper   = false
  lower   = true
  numeric  = true
  special = false
}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  env_name_lower = lower(var.ENV_NAME)
}
