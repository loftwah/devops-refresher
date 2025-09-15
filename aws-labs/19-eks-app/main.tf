data "terraform_remote_state" "alb_dns_cert" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/eks-alb-externaldns/terraform.tfstate"
    region       = "us-east-1"
    profile      = var.aws_profile
    use_lockfile = true
    encrypt      = true
  }
}

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/eks-cluster/terraform.tfstate"
    region       = "us-east-1"
    profile      = var.aws_profile
    use_lockfile = true
    encrypt      = true
  }
}

data "terraform_remote_state" "sg" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/security-groups/terraform.tfstate"
    region       = "us-east-1"
    profile      = var.aws_profile
    use_lockfile = true
    encrypt      = true
  }
}

data "terraform_remote_state" "rds" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/rds/terraform.tfstate"
    region       = "us-east-1"
    profile      = var.aws_profile
    use_lockfile = true
    encrypt      = true
  }
}

data "terraform_remote_state" "redis" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/redis/terraform.tfstate"
    region       = "us-east-1"
    profile      = var.aws_profile
    use_lockfile = true
    encrypt      = true
  }
}

data "terraform_remote_state" "s3app" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/s3/terraform.tfstate"
    region       = "us-east-1"
    profile      = var.aws_profile
    use_lockfile = true
    encrypt      = true
  }
}

locals {
  cluster_name = try(data.terraform_remote_state.eks.outputs.cluster_name, "devops-refresher-staging")
  cert_arn     = try(data.terraform_remote_state.alb_dns_cert.outputs.certificate_arn, "")
  oidc_url     = try(data.terraform_remote_state.eks.outputs.oidc_provider_url, null)
  oidc_arn     = try(data.terraform_remote_state.eks.outputs.oidc_provider_arn, null)
  db_host      = try(data.terraform_remote_state.rds.outputs.db_host, null)
  db_port      = try(data.terraform_remote_state.rds.outputs.db_port, null)
  db_name      = try(data.terraform_remote_state.rds.outputs.db_name, null)
  db_user      = try(data.terraform_remote_state.rds.outputs.db_user, null)
  redis_host   = try(data.terraform_remote_state.redis.outputs.redis_host, null)
  redis_port   = try(data.terraform_remote_state.redis.outputs.redis_port, null)
  s3_bucket    = try(data.terraform_remote_state.s3app.outputs.bucket_name, null)
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "app_irsa" {
  name = "eks-app-${var.namespace}-${var.release_name}-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = local.oidc_arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${trimprefix(local.oidc_url, "https://")}:sub" = "system:serviceaccount:${var.namespace}:${var.release_name}-demo-app",
            "${trimprefix(local.oidc_url, "https://")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "app_s3_write" {
  name = "eks-app-${var.namespace}-${var.release_name}-s3"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ],
        Resource = [
          "arn:aws:s3:::${local.s3_bucket}/app/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app_attach" {
  role       = aws_iam_role.app_irsa.name
  policy_arn = aws_iam_policy.app_s3_write.arn
}
data "aws_secretsmanager_secret_version" "db_pass" {
  count     = var.enable_externalsecrets ? 0 : 1
  secret_id = try(data.terraform_remote_state.rds.outputs.db_password_secret_arn, "")
}

data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = local.cluster_name
}

resource "helm_release" "app" {
  name         = var.release_name
  namespace    = var.namespace
  repository   = null
  chart        = "${path.root}/../kubernetes/helm/demo-app"
  timeout      = 600
  force_update = true
  wait         = false

  values = [
    yamlencode({
      image = {
        repository = var.image_repository
        digest     = var.image_tag # when set to a sha256 digest; pipeline sets this value
        pullPolicy = "Always"
      }
      service = {
        type = "ClusterIP"
        port = 3000
      }
      containerPort = 3000
      ingress = {
        enabled        = var.ingress_enabled
        className      = "alb"
        host           = var.host
        certificateArn = local.cert_arn
        annotations = {
          "alb.ingress.kubernetes.io/healthcheck-path" = "/healthz"
        }
      }
      podLabels = {
        app = "demo-node-app"
      }
      serviceAccount = {
        create = true
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.app_irsa.arn
        }
      }
      externalSecrets = var.enable_externalsecrets ? {
        enabled          = true
        targetSecretName = "demo-app-env"
        storeRef = {
          kind = "ClusterSecretStore"
          name = "aws-parameterstore"
        }
        dataFrom = [{ extract = { key = "/devops-refresher/staging/app" } }]
        } : {
        enabled          = false
        targetSecretName = null
        storeRef         = null
        dataFrom         = []
      }
      env = (
        var.enable_externalsecrets ? [
          { name = "DEPLOY_PLATFORM", value = "eks" }
          ] : [
          { name = "DEPLOY_PLATFORM", value = "eks" },
          { name = "APP_ENV", value = "staging" },
          { name = "PORT", value = "3000" },
          { name = "S3_BUCKET", value = tostring(local.s3_bucket) },
          { name = "DB_HOST", value = tostring(local.db_host) },
          { name = "DB_PORT", value = tostring(local.db_port) },
          { name = "DB_USER", value = tostring(local.db_user) },
          { name = "DB_NAME", value = tostring(local.db_name) },
          { name = "DB_PASS", value = try(one(data.aws_secretsmanager_secret_version.db_pass[*].secret_string), "") },
          { name = "DB_SSL", value = "required" },
          { name = "REDIS_HOST", value = tostring(local.redis_host) },
          { name = "REDIS_PORT", value = tostring(coalesce(local.redis_port, 6379)) },
          { name = "REDIS_TLS", value = "true" }
        ]
      )
    })
  ]
}

