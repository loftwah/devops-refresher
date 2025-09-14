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

# Pull app security group from Lab 07 so we can attach it to pods automatically
data "terraform_remote_state" "sg" {
  backend = "s3"
  config = {
    bucket  = "tf-state-139294524816-us-east-1"
    key     = "staging/security-groups/terraform.tfstate"
    region  = "us-east-1"
    profile = "devops-sandbox"
  }
}

# Pull runtime config from existing labs so we can inject env vars directly
data "terraform_remote_state" "s3" {
  backend = "s3"
  config = {
    bucket  = "tf-state-139294524816-us-east-1"
    key     = "staging/s3/terraform.tfstate"
    region  = "us-east-1"
    profile = "devops-sandbox"
  }
}

data "terraform_remote_state" "rds" {
  backend = "s3"
  config = {
    bucket  = "tf-state-139294524816-us-east-1"
    key     = "staging/rds/terraform.tfstate"
    region  = "us-east-1"
    profile = "devops-sandbox"
  }
}

data "terraform_remote_state" "redis" {
  backend = "s3"
  config = {
    bucket  = "tf-state-139294524816-us-east-1"
    key     = "staging/redis/terraform.tfstate"
    region  = "us-east-1"
    profile = "devops-sandbox"
  }
}

# Read DB password from Secrets Manager (created by lab 09). This only reads; does not modify lab 11/09.
data "aws_secretsmanager_secret" "db_pass" {
  name = "/devops-refresher/staging/app/DB_PASS"
}

data "aws_secretsmanager_secret_version" "db_pass" {
  secret_id = data.aws_secretsmanager_secret.db_pass.id
}

locals {
  cert_arn = try(data.terraform_remote_state.alb.outputs.certificate_arn, null)
}

resource "helm_release" "demo_app" {
  name             = var.release_name
  namespace        = var.namespace
  create_namespace = true
  chart            = "${path.root}/../kubernetes/helm/demo-app"
  timeout          = 900
  wait             = true

  set = concat(
    [
      { name = "image.repository", value = var.image_repository },
      { name = "image.tag", value = var.image_tag },
      { name = "containerPort", value = "3000" },
      { name = "service.port", value = "3000" },
      { name = "ingress.className", value = "alb" },
      { name = "ingress.enabled", value = var.ingress_enabled ? "true" : "false" },
      { name = "ingress.host", value = var.host },
      { name = "externalSecrets.enabled", value = var.enable_externalsecrets ? "true" : "false" },
      # Healthcheck hint so targets go healthy quickly
      { name = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/healthcheck-path", value = "/healthz" },
      { name = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/success-codes", value = "200-399" },
      # Explicit env to avoid DB dependency on boot
      { name = "env[0].name", value = "APP_ENV" },
      { name = "env[0].value", value = "staging", type = "string" },
      { name = "env[1].name", value = "PORT" },
      { name = "env[1].value", value = "3000", type = "string" },
      { name = "env[2].name", value = "SELF_TEST_ON_BOOT" },
      { name = "env[2].value", value = "false", type = "string" },
      { name = "env[3].name", value = "S3_BUCKET" },
      { name = "env[3].value", value = data.terraform_remote_state.s3.outputs.bucket_name, type = "string" },
      { name = "env[4].name", value = "DB_HOST" },
      { name = "env[4].value", value = data.terraform_remote_state.rds.outputs.db_host, type = "string" },
      { name = "env[5].name", value = "DB_PORT" },
      { name = "env[5].value", value = tostring(try(data.terraform_remote_state.rds.outputs.db_port, 5432)), type = "string" },
      { name = "env[6].name", value = "DB_USER" },
      { name = "env[6].value", value = data.terraform_remote_state.rds.outputs.db_user, type = "string" },
      { name = "env[7].name", value = "DB_NAME" },
      { name = "env[7].value", value = data.terraform_remote_state.rds.outputs.db_name, type = "string" },
      { name = "env[8].name", value = "DB_SSL" },
      { name = "env[8].value", value = "required", type = "string" },
      { name = "env[9].name", value = "DB_PASS" },
      { name = "env[9].value", value = data.aws_secretsmanager_secret_version.db_pass.secret_string, type = "string" },
      { name = "env[10].name", value = "REDIS_HOST" },
      { name = "env[10].value", value = data.terraform_remote_state.redis.outputs.redis_host, type = "string" },
      { name = "env[11].name", value = "REDIS_PORT" },
      { name = "env[11].value", value = tostring(try(data.terraform_remote_state.redis.outputs.redis_port, 6379)), type = "string" },
      { name = "env[12].name", value = "REDIS_TLS" },
      { name = "env[12].value", value = "true", type = "string" }
    ],
    local.cert_arn != null ? [{ name = "ingress.certificateArn", value = local.cert_arn }] : []
  )
}

data "kubernetes_ingress_v1" "demo" {
  metadata {
    name      = "${var.release_name}-demo-app"
    namespace = var.namespace
  }
  depends_on = [helm_release.demo_app]
}

output "ingress_hostname" {
  description = "ALB DNS name for the app ingress"
  value       = try(data.kubernetes_ingress_v1.demo.status[0].load_balancer[0].ingress[0].hostname, null)
}
