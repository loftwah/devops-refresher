# ADR-003: Security Group Strategy

## Context

- Multiple resources require SGs: ALB, ECS tasks, RDS, Redis.
- We want reuse where appropriate and least-privilege between tiers.

## Decision

- Shared SGs (central):
  - `alb_sg`: ingress 80/443 from internet; egress all. Lives in Lab 07.
  - `app_sg`: ingress app port from `alb_sg`; egress all. Lives in Lab 07.
- Resource SGs (local to resource labs):
  - `rds_sg`: ingress 5432 only from `app_sg`.
  - `redis_sg`: ingress 6379 only from `app_sg`.

## Rationale

- Keeps common, cross-cutting SGs in one place to avoid duplication.
- Resource SGs evolve with their service and encode their least-privileged intent.

## Considerations

- Outbound access: `app_sg` egress all (simple for demo); tighten if required.
- EKS: if used, secure via worker node/pod SGs and the same `app_sg` ingress principle.
- ALB to targets: Use the `app_sg` on tasks/pods and allow only the container port.
- VPC Endpoints: Already configured; can further restrict egress if locking down to endpoints.

## Checklist

- [x] `alb_sg` and `app_sg` created and exported
- [x] `rds_sg` allows 5432 from `app_sg` only
- [x] `redis_sg` allows 6379 from `app_sg` only
- [x] ECS service uses `app_sg`; ALB uses `alb_sg`
