data "aws_eks_cluster" "this" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}

data "terraform_remote_state" "alb" {
  backend = "s3"
  config = {
    bucket  = "tf-state-139294524816-us-east-1"
    key     = "staging/eks-alb-externaldns/terraform.tfstate"
    region  = "us-east-1"
    profile = "devops-sandbox"
  }
}

locals {
  cert_arn = try(data.terraform_remote_state.alb.outputs.certificate_arn, null)
}

resource "helm_release" "demo_app" {
  name             = var.release_name
  namespace        = var.namespace
  create_namespace = true
  chart            = "${path.root}/../kubernetes/helm/demo-app"

  set = concat(
    [
      { name = "image.tag",               value = var.image_tag },
      { name = "ingress.host",            value = var.host },
      { name = "externalSecrets.enabled",  value = var.enable_externalsecrets ? "true" : "false" }
    ],
    local.cert_arn != null ? [ { name = "ingress.certificateArn", value = local.cert_arn } ] : []
  )
}

data "kubernetes_ingress_v1" "demo" {
  metadata {
    name      = var.release_name
    namespace = var.namespace
  }
  depends_on = [helm_release.demo_app]
}

output "ingress_hostname" {
  description = "ALB DNS name for the app ingress"
  value       = try(data.kubernetes_ingress_v1.demo.status[0].load_balancer[0].ingress[0].hostname, null)
}
