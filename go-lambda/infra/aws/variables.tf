variable "ENV_NAME" {
  type        = string
  description = "Name of the environment being created"
  nullable    = false
  validation {
    condition     = length(var.ENV_NAME) < 5
    error_message = "Environment variable should be less than or equal to 4 letters."
  }
}
variable "AWS_ENV_AUTH" {
  type        = string
  description = "Authentication profile for AWS"
  default     = "core-infra"
}
variable "AWS_ENV_REGION" {
  type        = string
  description = "AWS Region to build"
  default     = "us-east-1"
}
