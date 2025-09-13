variable "region" {
  description = "AWS region for ESO access"
  type        = string
  default     = "ap-southeast-2"
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider_url" {
  type = string
}

variable "namespace" {
  type    = string
  default = "external-secrets"
}

variable "service_account" {
  type    = string
  default = "external-secrets"
}

variable "ssm_path_prefix" {
  type = string
}

variable "secrets_prefix" {
  type = string
}

variable "role_name" {
  type    = string
  default = "eks-external-secrets"
}
