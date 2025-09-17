# ElastiCache (Redis)

## Objectives

- Provision a Redis replication group in private subnets for caching.
- Expose outputs for host and port consumed by Parameter Store and app.

## Prerequisites

- VPC with private subnets and NAT.
- Security group for app tasks/pods to allow outbound to Redis port (6379).

## Tasks

1. Subnet group and security groups

```hcl
resource "aws_elasticache_subnet_group" "this" {
  name       = "redis-app"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "redis" {
  name   = "redis-app"
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "from_app_sg" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = var.app_sg_id
}
```

2. Replication group (provider v5 schema)

```hcl
resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "app-redis"
  description          = "Redis for app"
  engine               = "redis"
  engine_version       = "7.0"
  node_type            = var.node_type
  # v5: use node group fields instead of number_cache_clusters
  num_node_groups            = 1
  replicas_per_node_group    = 0
  automatic_failover_enabled = false
  subnet_group_name          = aws_elasticache_subnet_group.this.name
  security_group_ids         = [aws_security_group.redis.id]
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
}
```

3. Outputs

```hcl
output "redis_host" { value = aws_elasticache_replication_group.this.primary_endpoint_address }
output "redis_port" { value = aws_elasticache_replication_group.this.port }
```

## Acceptance Criteria

- Redis endpoint available in private subnets.
- Only app SG allowed inbound on 6379.
- Outputs present for host and port.
