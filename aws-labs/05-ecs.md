# Lab 05: ECS Cluster, Task Definition, and Service

## Objectives

- Stand up an ECS Fargate cluster, a task definition, and a service wired to the ALB.

## Tasks

1. Create ECS cluster (enable Container Insights optional).
2. Create CloudWatch log group (retention 14d).
3. Define task definition: image from ECR `:staging`, port 80, logs via `awslogs`.
4. Create service: Fargate, subnets = private, SG allows from ALB SG, attach to target group.

## Acceptance Criteria

- Service reaches steady state; target group shows healthy targets.
- ALB DNS returns 200 OK from the sample container.

## Hints

- If health checks fail, confirm port mapping, path `/health`, and SG rules.
- Use deployment circuit breaker to auto-rollback on failures.
