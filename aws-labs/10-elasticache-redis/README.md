# Lab 10 – ElastiCache (Redis)

## What Terraform Actually Creates (main.tf)

- Reads VPC, private subnets, and `app_sg_id` from remote state when not provided.
- `aws_elasticache_subnet_group.this` for private subnet placement.
- `aws_security_group.redis` with ingress 6379 only from `app_sg_id`.
- `aws_elasticache_replication_group.this`:
  - Engine `redis` 7.0, `cache.t4g.micro` by default.
  - Provider v5 schema: `num_node_groups = 1`, `replicas_per_node_group = 0` (single‑node) and `automatic_failover_enabled = false`.
  - At‑rest and transit encryption enabled.
- Outputs: `redis_host`, `redis_port`, `redis_sg_id`.

## Variables (variables.tf)

- `vpc_id`, `private_subnet_ids`, `app_sg_id`: optional; auto‑discovered from prior labs if empty.
- `node_type` (default `cache.t4g.micro`).

## Apply

```bash
cd aws-labs/10-elasticache-redis
terraform init
terraform apply -auto-approve
```

## Security and Connectivity

- Redis runs in private subnets; inbound only from `app_sg_id` on 6379.
- Transit encryption is enabled, so clients should use `rediss://` and TLS.

## How Other Labs Use This

- Parameter Store (Lab 11) reads `redis_host` and `redis_port` and writes `REDIS_HOST`, `REDIS_PORT`, and a convenience `REDIS_URL=rediss://<host>:<port>`.
- Workloads fetch non‑secrets from SSM and connect using TLS.

## Outputs

- `redis_host`, `redis_port`, `redis_sg_id`.

## Cleanup

```bash
terraform destroy -auto-approve
```
