data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/network/terraform.tfstate"
    region       = "us-east-1"
    profile      = "devops-sandbox"
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
    profile      = "devops-sandbox"
    use_lockfile = true
    encrypt      = true
  }
}

locals {
  vpc_id_effective             = length(var.vpc_id) > 0 ? var.vpc_id : data.terraform_remote_state.vpc.outputs.vpc_id
  private_subnet_ids_effective = length(var.private_subnet_ids) > 0 ? var.private_subnet_ids : data.terraform_remote_state.vpc.outputs.private_subnet_ids
  app_sg_id_effective          = length(var.app_sg_id) > 0 ? var.app_sg_id : data.terraform_remote_state.sg.outputs.app_sg_id
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "staging-redis-app"
  subnet_ids = local.private_subnet_ids_effective
}

resource "aws_security_group" "redis" {
  name        = "staging-redis-app"
  description = "Redis access for app"
  vpc_id      = local.vpc_id_effective
}

resource "aws_security_group_rule" "from_app_sg" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = local.app_sg_id_effective
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "staging-app-redis"
  description          = "Redis for app"
  engine               = "redis"
  engine_version       = "7.0"
  node_type            = var.node_type
  # Terraform AWS provider v5 removed number_cache_clusters; use these instead
  num_node_groups            = 1
  replicas_per_node_group    = 0
  automatic_failover_enabled = false
  subnet_group_name          = aws_elasticache_subnet_group.this.name
  security_group_ids         = [aws_security_group.redis.id]
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  # Note: ElastiCache creates can take ~5–15 minutes.
  # See docs/terraform-apply-troubleshooting.md for guidance on durations and troubleshooting.
}
