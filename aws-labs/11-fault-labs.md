# Lab 11: Fault Labs (Troubleshooting on ECS and EKS)

## Objectives

- Introduce common failure modes and practice troubleshooting with targeted scripts and AWS CLI/kubectl commands.

## Scenarios

1. Health check failures (wrong path/port) → ALB 5xx, target unhealthy.
2. CPU/memory throttling and OOMKilled.
3. Network egress blocked (SG/NACL) → NAT/Internet failures.
4. DNS failures (no resolver, wrong DNS name, missing Route53 record).
5. IAM denied (task role/service account missing permissions for S3/SSM/ECR).

## What to Practice

- ECS: `aws logs tail`, `aws ecs describe-services`, `aws ecs list-tasks`, `aws ecs execute-command`.
- EKS: `kubectl get/describe logs exec`, `kubectl events`, `kubectl top`, `kubectl rollout status`.
- ALB/NLB: Target health, 5xx metrics, access logs (if enabled).
- CloudWatch Logs insights queries for quick error patterns.

## Acceptance Criteria

- You can identify the root cause for each scenario and restore health.
- Scripts under `scripts/` speed up inspection (logs, exec, env, routes).
