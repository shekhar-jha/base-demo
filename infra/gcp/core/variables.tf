variable "ENV_NAME" {
  type        = string
  description = "Name of the environment being created"
  nullable    = false
  validation {
    condition     = length(var.ENV_NAME) < 5
    error_message = "Environment variable can be upto 4 letters."
  }
}
variable "GCP_REGION" {
  type        = string
  description = "Name of default region where resource should be managed"
}
variable "GCP_PROJECT" {
  type        = string
  description = "Name of the project in which resource should be managed."
}
variable "TF_ENV" {
  type = object({
    http_proxy = string
  })
  default = {
    http_proxy = ""
  }
}
variable "GITHUB_REPO" {
  type = object({
    repo_owner = string
    repo_name  = string
  })
  default = {
    repo_owner = "shekhar-jha"
    repo_name  = "base-demo"
  }
}