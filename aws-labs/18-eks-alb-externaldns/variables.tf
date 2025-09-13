variable "hosted_zone_name" {
  description = "Public hosted zone for labs (e.g., aws.deanlofts.xyz)"
  type        = string
  default     = "aws.deanlofts.xyz"
}

variable "eks_domain_fqdn" {
  description = "EKS app domain FQDN"
  type        = string
  default     = "demo-node-app-eks.aws.deanlofts.xyz"
}

variable "oidc_provider_arn" {
  description = "EKS cluster OIDC provider ARN (for IRSA)"
  type        = string
}

variable "lbc_namespace" {
  description = "Namespace for AWS Load Balancer Controller SA"
  type        = string
  default     = "kube-system"
}

variable "lbc_service_account" {
  description = "ServiceAccount name for AWS Load Balancer Controller"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "externaldns_namespace" {
  description = "Namespace for ExternalDNS SA"
  type        = string
  default     = "external-dns"
}

variable "externaldns_service_account" {
  description = "ServiceAccount name for ExternalDNS"
  type        = string
  default     = "external-dns"
}
