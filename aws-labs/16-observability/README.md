Observability (CloudWatch): Logs, Metrics, Alerts, Dashboard

What this adds

- SNS topic `devops-refresher-staging-alerts` with email subscription to `dean+aws@deanlofts.xyz`.
- CloudWatch alarms:
  - ECS service CPU/Memory high (>= 80%).
  - ALB 5XX (ELB and target) and latency p95 > 1.5s.
  - Target group UnHealthyHostCount > 0.
  - RDS CPU high, FreeStorage low (< 2 GiB), FreeableMemory low.
  - Redis CPU high and Evictions > 0.
- CloudWatch dashboard `devops-refresher-staging` with ECS, ALB, RDS, Redis widgets.

Assumptions

- Uses existing remote states from labs 12 (ALB), 13 (ECS cluster), 14 (ECS service), 09 (RDS), 10 (Redis).
- Naming matches existing resources (e.g., RDS `staging-app-postgres`, Redis replication group `staging-app-redis`).
- ECS task definition is already logging to CloudWatch Logs `/aws/ecs/devops-refresher-staging` (from lab 13).

Usage

1. Initialize and apply:

   terraform -chdir=aws-labs/16-observability init
   terraform -chdir=aws-labs/16-observability apply -auto-approve

2. Confirm the email subscription sent to `dean+aws@deanlofts.xyz` so alarms can notify.

Notes

- Assumes RDS and Redis labs are applied; alarms and widgets are created automatically.

Notes

- Alarms treat missing data as not breaching to avoid false positives during deploys.
- Thresholds are sane defaults; adjust via variables if needed.
- Dashboard renders in CloudWatch under `devops-refresher-staging`.
