# Resource Reference & Checklists

Use this as a quick checklist while building. Each section lists required, optional, and validation steps.

## VPC & Subnets

- Required: VPC CIDR; 2+ public + 2+ private subnets; IGW; NAT GW; route tables.
- Optional: VPC endpoints (SSM, ECR, CloudWatch Logs), Flow Logs.
- Validate: Routes per subnet; NAT for private subnets; AZ distribution.

## Security Groups

- Required: ALB SG (80/443 inbound from 0.0.0.0/0), ECS SG (inbound from ALB SG, app port only).
- Optional: Egress lock-down by destination prefix lists; SG referencing SG.
- Validate: Connections via `curl` and AWS reachability analyzer.

## ALB + Target Groups + Listeners

- Required: ALB across public subnets; TG protocol/port/health check; listeners 80→redirect, 443→forward.
- Optional: Listener rules by path/host; WAF; access logs to S3.
- Validate: ALB DNS serves 200; TG shows healthy targets.

## ACM Certificates

- Required: Issued public cert in region of ALB; validation complete.
- Optional: Multi-domain SANs; auto-renew.
- Validate: Listener attaches cert; browser shows valid TLS.

## Route53

- Required: Hosted zone; record (A/AAAA alias) to ALB.
- Optional: Weighted, latency, or failover routing; health checks.
- Validate: `dig` resolves; HTTPS works on hostname.

## ECR

- Required: Repo per app; immutable tags recommended; scan on push.
- Optional: Lifecycle policies (expire old tags); encryption with KMS.
- Validate: Push/pull; image tag resolves in deploy logs.

## IAM

- Required: Task execution role (ECR pull, logs:Create* Put*); Task role (least-privileged runtime permissions).
- Optional: Boundary policies; attribute-based access control via tags.
- Validate: ECS tasks start without permission errors; can fetch params/secrets.

## ECS Cluster / Services / Task Definitions

- Required: Cluster (Fargate); Task definitions (CPU/mem, image, port, env, logs); Service (desired, TG, deployment).
- Optional: Capacity providers; circuit breaker; service autoscaling; exec.
- Validate: Service steady state; targets healthy; logs present.

## Parameters & Secrets

- Required: Parameter Store (SecureString) or Secrets Manager; least-privilege policies.
- Optional: Hierarchical param paths per env/app; rotation for secrets.
- Validate: App reads values; no secrets in TF state or logs.

## CloudWatch

- Required: Log groups per service; metrics dashboards minimal.
- Optional: Alarms for 5XX, latency, CPU/mem; SLOs; synthetic canaries.
- Validate: Logs flowing; alerts fire under induced failures.

## CI/CD (CodePipeline + CodeBuild)

- Required: Build spec (Docker build/push); artifact with image URI; deploy stage updating task definition.
- Optional: Manual approvals; Slack/Webhook notifications; blue/green deploy.
- Validate: Commit triggers build → deploy → healthy service.
