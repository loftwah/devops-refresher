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
          "s3:GetObject",
          "s3:DeleteObject"
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
  depends_on   = [kubernetes_secret_v1.app_env]

  values = [
    yamlencode({
      image = {
        repository = var.image_repository
        digest     = var.image_tag # when set to a sha256 digest; pipeline sets this value
        tag        = "staging"
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
      # Provide env via a referenced Secret to avoid array merge quirks
      envSecretName = "demo-node-app-env"
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
      env = [
        { name = "DEPLOY_PLATFORM", value = "eks" }
      ]
    })
  ]
}

# Provide application environment via a Kubernetes Secret referenced by envFrom
resource "kubernetes_secret_v1" "app_env" {
  metadata {
    name      = "demo-node-app-env"
    namespace = var.namespace
    labels = {
      app = "demo-node-app"
    }
  }
  type = "Opaque"
  data = {
    APP_ENV   = "staging"
    PORT      = "3000"
    S3_BUCKET = tostring(local.s3_bucket)

    DB_HOST = tostring(local.db_host)
    DB_PORT = tostring(local.db_port)
    DB_USER = tostring(local.db_user)
    DB_NAME = tostring(local.db_name)
    DB_PASS = try(one(data.aws_secretsmanager_secret_version.db_pass[*].secret_string), "")
    DB_SSL  = "required"

    REDIS_HOST = tostring(local.redis_host)
    REDIS_PORT = tostring(coalesce(local.redis_port, 6379))
    REDIS_TLS  = "true"
  }
}

