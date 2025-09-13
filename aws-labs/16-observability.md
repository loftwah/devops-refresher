# 16 – Observability (CloudWatch Logs, Metrics, Alarms, Dashboard)

## Objectives

- Centralize logs and key service metrics in CloudWatch.
- Alert operators on service degradation via SNS email.
- Provide a one‑page CloudWatch dashboard for ECS, ALB, RDS, and Redis.

## Prerequisites

- 12 – ALB, 13 – ECS Cluster, 14 – ECS Service applied (remote state available).
- 09 – RDS and 10 – ElastiCache (Redis) applied if you want those alarms/widgets.
- ECS service logs to CloudWatch using the `awslogs` driver (already configured in 13/14 labs).

## What this lab creates

- SNS topic `devops-refresher-staging-alerts` with email subscription to `dean+aws@deanlofts.xyz`.
- CloudWatch alarms:
  - ECS: CPU >= 80%, Memory >= 80%, and app log ERRORs (>0 in 5m).
  - ALB: ELB 5XX and Target 5XX (>5 in 5m), TargetResponseTime p95 > 1.5s, UnHealthyHostCount > 0.
  - RDS: CPU >= 80%, FreeStorage < 2 GiB, FreeableMemory < 100 MiB.
  - Redis: CPU >= 80%, Evictions > 0.
- CloudWatch dashboard `devops-refresher-staging` with ECS, ALB, RDS, and Redis widgets.

## Apply

- Initialize and apply:

  terraform -chdir=aws-labs/16-observability init
  terraform -chdir=aws-labs/16-observability apply -auto-approve

- Confirm the SNS email subscription sent to `dean+aws@deanlofts.xyz` (check inbox) so alarms can notify.

## Validation

- Dashboard: Open CloudWatch -> Dashboards -> `devops-refresher-staging`.
- ALB 5XX: Hit a non-existent endpoint repeatedly to generate Target 5XX, or temporarily stop tasks to trigger UnHealthyHostCount.
- ECS CPU/Memory: Apply a temporary load test; verify alarms when thresholds are exceeded.
- Log error alarm: Emit an `ERROR` line from the app and confirm an alarm notification.
- RDS/Redis: Observe widgets/alarms (free storage, memory, evictions) if those labs are deployed.

## Validate (Automated)

- Run the validator from repo root:

  aws-labs/scripts/validate-observability.sh

- Or run all validators, including observability:

  aws-labs/scripts/validate-labs.sh

## Variables

- See `aws-labs/16-observability/variables.tf` for defaults (env, service name, alert email).

## Cleanup

- Keep for staging. To remove:

  terraform -chdir=aws-labs/16-observability destroy
