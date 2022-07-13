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
variable "GCP_ID" {
  type        = string
  description = "User Identity being used to run the terraform script"
}