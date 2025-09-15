variable "namespace" {
  description = "Kubernetes namespace for the app"
  type        = string
  default     = "demo"
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "demo-eks"
}

variable "image_tag" {
  description = "Image digest (sha256:...) to deploy; pipeline sets this"
  type        = string
  default     = ""
}

variable "image_repository" {
  description = "Container image repository"
  type        = string
  default     = "139294524816.dkr.ecr.ap-southeast-2.amazonaws.com/demo-node-app"
}

variable "host" {
  description = "Ingress host for the app"
  type        = string
  default     = "demo-node-app-eks.aws.deanlofts.xyz"
}

variable "ingress_enabled" {
  description = "Enable ALB Ingress"
  type        = bool
  default     = true
}

variable "enable_externalsecrets" {
  description = "Whether to enable External Secrets in values"
  type        = bool
  default     = false
}

