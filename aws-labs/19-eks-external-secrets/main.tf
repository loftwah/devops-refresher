data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket  = "tf-state-139294524816-us-east-1"
    key     = "staging/eks-cluster/terraform.tfstate"
    region  = "us-east-1"
    profile = "devops-sandbox"
  }
}

locals {
  oidc_provider_arn = coalesce(var.oidc_provider_arn, data.terraform_remote_state.eks.outputs.oidc_provider_arn)
  oidc_provider_url = coalesce(var.oidc_provider_url, data.terraform_remote_state.eks.outputs.oidc_provider_url)
  oidc_sub          = replace(local.oidc_provider_url, "https://", "")
}

# EKS cluster connection (for Kubernetes/Helm providers)
data "aws_eks_cluster" "this" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_sub}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_sub}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eso" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "read" {
  statement {
    effect  = "Allow"
    actions = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = [
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_path_prefix}/*"
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [
      "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.secrets_prefix}-*"
    ]
  }
}

resource "aws_iam_policy" "read" {
  name   = "ExternalSecretsReadConfig"
  policy = data.aws_iam_policy_document.read.json
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.eso.name
  policy_arn = aws_iam_policy.read.arn
}

# Optional: Install ESO and create ClusterSecretStores via Terraform
resource "helm_release" "external_secrets" {
  count            = var.manage_k8s ? 1 : 0
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = var.namespace
  create_namespace = true

  depends_on = [aws_iam_role_policy_attachment.attach]

  set = [
    { name = "installCRDs", value = "true" },
    { name = "serviceAccount.create", value = "true" },
    { name = "serviceAccount.name", value = var.service_account },
    { name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn", value = aws_iam_role.eso.arn }
  ]
}

resource "kubernetes_manifest" "clustersecretstore_parameterstore" {
  count      = var.manage_k8s ? 1 : 0
  depends_on = [helm_release.external_secrets]
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata   = { name = "aws-parameterstore" }
    spec = {
      provider = {
        aws = {
          service = "ParameterStore"
          region  = var.region
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = var.service_account
                namespace = var.namespace
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_manifest" "clustersecretstore_secretsmanager" {
  count      = var.manage_k8s ? 1 : 0
  depends_on = [helm_release.external_secrets]
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata   = { name = "aws-secretsmanager" }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.region
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = var.service_account
                namespace = var.namespace
              }
            }
          }
        }
      }
    }
  }
}
