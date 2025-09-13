variable "region" {
  description = "AWS region for ESO access"
  type        = string
  default     = "ap-southeast-2"
}

variable "oidc_provider_arn" {
  description = "EKS cluster OIDC provider ARN. Optional: auto-read from Lab 17 remote state if null."
  type        = string
  default     = null
}

variable "oidc_provider_url" {
  description = "EKS cluster OIDC provider URL. Optional: auto-read from Lab 17 remote state if null."
  type        = string
  default     = null
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
  description = "SSM Parameter Store path prefix for config parameters"
  type        = string
  default     = "/devops-refresher/staging/app"
}

variable "secrets_prefix" {
  description = "Secrets Manager prefix (name prefix) for app secrets"
  type        = string
  default     = "/devops-refresher/staging/app"
}

variable "role_name" {
  type    = string
  default = "eks-external-secrets"
}

variable "manage_k8s" {
  description = "If true, Terraform installs ESO via Helm and applies ClusterSecretStores"
  type        = bool
  default     = false
}
