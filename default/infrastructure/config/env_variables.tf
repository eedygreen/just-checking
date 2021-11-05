variable "application_name" {
  description = "Application name"
  type        = string
}

variable "aws_profile" {
  description = "AWS Profile"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "environment" {
  description = "Environment name (used for tags)"
  type        = string
}

variable "role_arn" {
  description = "IAM ARN for role to assume"
  type        = string
}
