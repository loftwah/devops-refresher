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

## Why It Matters

- Clients silently fail when TLS or AUTH expectations don’t match. Eviction policy determines behavior under memory pressure — crucial for stability.

## Mental Model

- In‑transit encryption (TLS) and AUTH:
  - With transit encryption enabled, use `rediss://` and a TLS‑capable client.
  - AUTH can be enabled via user/password on Redis 6+ (Redis ACLs); align app config accordingly.
- Eviction policy: `volatile-lru`, `allkeys-lru`, `noeviction`, etc. Choose based on data criticality; `noeviction` forces writes to fail under pressure.

## Verification

```bash
# From the app environment (with network access), verify TLS connectivity
openssl s_client -connect <redis-host>:<port> -servername <redis-host> -brief
```

## Troubleshooting

- Connection reset/plaintext errors: you’re using `redis://` with TLS enabled — switch to `rediss://`.
- AUTH failures: ensure app uses the correct user/password if ACLs are enabled.

## Teardown Notes

- Destroy dependents first (ECS app), then the replication group, then the subnet group and SG.

## Check Your Understanding

- When would you choose `noeviction` vs an LRU policy?
- How does enabling transit encryption change your client connection string?
