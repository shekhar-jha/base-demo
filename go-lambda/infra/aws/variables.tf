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

variable "DOCKER_IMAGE_TYPE" {
  type        = string
  description = "Type of base image to use for build e.g. alpine, aws, scratch"
  default     = "scratch"
}

variable "PACKAGE_TYPE" {
  type        = string
  description = "Type of package to create for deployment e.g. zip|image"
  default     = "image"
  validation {
    condition     = lower(var.PACKAGE_TYPE) == "zip" || lower(var.PACKAGE_TYPE) == "image"
    error_message = "Only zip and image are supported at this time"
  }
}