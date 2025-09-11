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
  s3_bucket_effective   = length(var.s3_bucket) > 0 ? var.s3_bucket : data.terraform_remote_state.s3.outputs.bucket_name
  db_host_effective     = length(var.db_host) > 0 ? var.db_host : data.terraform_remote_state.rds.outputs.db_host
  db_port_effective     = var.db_port > 0 ? var.db_port : tonumber(data.terraform_remote_state.rds.outputs.db_port)
  db_user_effective     = length(var.db_user) > 0 ? var.db_user : data.terraform_remote_state.rds.outputs.db_user
  db_name_effective     = length(var.db_name) > 0 ? var.db_name : data.terraform_remote_state.rds.outputs.db_name
  redis_host_effective  = length(var.redis_host) > 0 ? var.redis_host : data.terraform_remote_state.redis.outputs.redis_host
  redis_port_effective  = var.redis_port > 0 ? var.redis_port : tonumber(data.terraform_remote_state.redis.outputs.redis_port)

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
  }
}

resource "aws_ssm_parameter" "app" {
  for_each = local.params
  name     = "/devops-refresher/${var.env}/${var.service}/${each.key}"
  type     = "String"
  value    = each.value
}

resource "aws_secretsmanager_secret" "app" {
  # Only create secrets when a non-null value is provided
  for_each = { for k, v in var.secret_values : k => v if v != null }
  name     = "/devops-refresher/${var.env}/${var.service}/${each.key}"
}

resource "aws_secretsmanager_secret_version" "app" {
  for_each      = { for k, v in var.secret_values : k => v if v != null }
  secret_id     = aws_secretsmanager_secret.app[each.key].id
  secret_string = each.value
}
