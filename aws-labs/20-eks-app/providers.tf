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

variable "aws_profile" {
  description = "AWS CLI/SDK profile"
  type        = string
  default     = "devops-sandbox"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket  = "tf-state-139294524816-us-east-1"
    key     = "staging/eks-cluster/terraform.tfstate"
    region  = "us-east-1"
    profile = "devops-sandbox"
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

