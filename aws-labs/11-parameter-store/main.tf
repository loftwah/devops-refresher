data "terraform_remote_state" "s3" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/s3/terraform.tfstate"
    region       = "us-east-1"
    profile      = "devops-sandbox"
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
    profile      = "devops-sandbox"
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
    profile      = "devops-sandbox"
    use_lockfile = true
    encrypt      = true
  }
}

locals {
  s3_bucket_effective  = length(var.s3_bucket) > 0 ? var.s3_bucket : data.terraform_remote_state.s3.outputs.bucket_name
  db_host_effective    = length(var.db_host) > 0 ? var.db_host : data.terraform_remote_state.rds.outputs.db_host
  db_port_effective    = var.db_port > 0 ? var.db_port : tonumber(data.terraform_remote_state.rds.outputs.db_port)
  db_user_effective    = length(var.db_user) > 0 ? var.db_user : data.terraform_remote_state.rds.outputs.db_user
  db_name_effective    = length(var.db_name) > 0 ? var.db_name : data.terraform_remote_state.rds.outputs.db_name
  redis_host_effective = length(var.redis_host) > 0 ? var.redis_host : data.terraform_remote_state.redis.outputs.redis_host
  # Default to 6379 if the redis lab state does not export `redis_port`
  redis_port_effective = var.redis_port > 0 ? var.redis_port : try(tonumber(data.terraform_remote_state.redis.outputs.redis_port), 6379)

  params = {
    APP_ENV           = var.env
    LOG_LEVEL         = "info"
    PORT              = "3000"
    DB_SSL            = "required"
    SELF_TEST_ON_BOOT = "false"
    S3_BUCKET         = local.s3_bucket_effective
    DB_HOST           = local.db_host_effective
    DB_PORT           = tostring(local.db_port_effective)
    DB_USER           = local.db_user_effective
    DB_NAME           = local.db_name_effective
    REDIS_HOST        = local.redis_host_effective
    REDIS_PORT        = tostring(local.redis_port_effective)
    REDIS_URL         = "rediss://${local.redis_host_effective}:${tostring(local.redis_port_effective)}"
  }
}

# Optionally auto-generate APP_AUTH_SECRET if not provided
resource "random_password" "app_auth_secret" {
  count   = var.auto_create_app_auth_secret && try(var.secret_values["APP_AUTH_SECRET"], null) == null ? 1 : 0
  length  = var.app_auth_secret_length
  special = false
}

resource "aws_ssm_parameter" "app" {
  for_each = local.params
  name     = "/devops-refresher/${var.env}/${var.service}/${each.key}"
  type     = "String"
  value    = each.value
}

resource "aws_secretsmanager_secret" "app" {
  # Create for provided values
  for_each = { for k, v in var.secret_values : k => v if v != null }
  name     = "/devops-refresher/${var.env}/${var.service}/${each.key}"
}

resource "aws_secretsmanager_secret_version" "app" {
  for_each      = { for k, v in var.secret_values : k => v if v != null }
  secret_id     = aws_secretsmanager_secret.app[each.key].id
  secret_string = each.value
}

# Auto-created APP_AUTH_SECRET path (when not provided)
resource "aws_secretsmanager_secret" "app_auth_secret_auto" {
  count = var.auto_create_app_auth_secret && try(var.secret_values["APP_AUTH_SECRET"], null) == null ? 1 : 0
  name  = "/devops-refresher/${var.env}/${var.service}/APP_AUTH_SECRET"
}

resource "aws_secretsmanager_secret_version" "app_auth_secret_auto" {
  count         = var.auto_create_app_auth_secret && try(var.secret_values["APP_AUTH_SECRET"], null) == null ? 1 : 0
  secret_id     = aws_secretsmanager_secret.app_auth_secret_auto[0].id
  secret_string = random_password.app_auth_secret[0].result
}
