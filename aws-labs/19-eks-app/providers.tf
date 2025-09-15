variable "aws_profile" {
  description = "AWS profile"
  type        = string
  default     = "devops-sandbox"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "tags" {
  description = "Base tags"
  type        = map(string)
  default = {
    Owner       = "Dean Lofts"
    Project     = "devops-refresher"
    App         = "devops-refresher"
    Environment = "staging"
    ManagedBy   = "Terraform"
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
  default_tags { tags = var.tags }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10"
    }
  }
}

# Kubernetes and Helm providers point to the EKS cluster from Lab 17
provider "kubernetes" {
  host                   = try(data.aws_eks_cluster.this.endpoint, null)
  cluster_ca_certificate = try(base64decode(data.aws_eks_cluster.this.certificate_authority[0].data), null)
  token                  = try(data.aws_eks_cluster_auth.this.token, null)
}

provider "helm" {
  kubernetes = {
    host                   = try(data.aws_eks_cluster.this.endpoint, null)
    cluster_ca_certificate = try(base64decode(data.aws_eks_cluster.this.certificate_authority[0].data), null)
    token                  = try(data.aws_eks_cluster_auth.this.token, null)
  }
}
