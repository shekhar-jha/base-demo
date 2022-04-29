variable "ENV_NAME" {
  type = string
  description = "Name of the environment being created"
  nullable = false
  validation {
    condition = length(var.ENV_NAME) != 4
    error_message = "Environment variable should be 4 letter."
  }
}
variable "AWS_ENV_AUTH" {
  type = string
  description = "Authentication profile for AWS"
  default = "core-infra"
}

variable "AWS_ENV" {
  type = object({
    region = string
    default_tags = map(string)
    
  })
  description = "Basic AWS environment configuration"
  default = {
    region = "us-east-1"
    default_tags = {}
  }
}
variable "TF_ENV" {
  type = object({
    http_proxy = string
  })
  default = {
    http_proxy = ""
  }
}
variable "INFRA_CIDR" {
  type = string
}
