# Labs Overview Cheat Sheet

- 00 Backend: Remote state S3/DynamoDB. Verify: `terraform output` shows bucket and table; writes succeed.
- 01 VPC: 2 public + 2 private subnets, NAT, IGW. Verify: route tables `0.0.0.0/0` to IGW (public) and NAT (private).
- 02 Endpoints: S3 Gateway + interface endpoints (SSM/ECR/Logs). Verify: VPC → Endpoints list shows expected services, Private DNS enabled.
- 03 ECR: Repo with scan-on-push + lifecycle policy. Verify: `aws ecr describe-repositories` and `describe-images` show tags.
- 05 DNS: Delegated subdomain. Verify: NS records match Route 53; test A/AAAA/CNAME resolution.
- 06 IAM: Task execution + task roles. Verify: roles exist, policies attached, `iam:PassRole` scoped to ECS.
- 07 SGs: ALB SG + app SG. Verify: only ALB→app ingress on app port; least-priv egress.
- 08 S3: Private, versioned bucket with BPA on. Verify: denies public ACL/policy; SSE-S3 enabled.
- 09 RDS: Private Postgres with SG-only ingress, secret in Secrets Manager. Verify: endpoint reachable from app SG only.
- 10 Redis: Private, TLS on. Verify: `rediss://` connectivity; no plaintext.
- 11 Param Store: Publishes non-secrets for app. Verify: parameters exist with expected values.
- 12 ALB: Listener + TG. Verify: health checks and HTTPS listener.
- 13 ECS Cluster: Container Insights on. Verify: cluster ACTIVE, insights enabled.
- 14 ECS Service: Fargate, awslogs, ECS Exec. Verify: tasks RUNNING, logs in CloudWatch, `ecs execute-command` works.
- 15 ECS CI/CD: CodePipeline to ECS. Verify: pipeline succeeds; task definition updated.
- 16 Observability: Alarms + dashboard. Verify: dashboard in CW; alarms in OK.
- 17–21 EKS: Cluster → ALB/ExternalDNS → App → CI/CD. Verify: `kubectl` objects READY; Ingress DNS works.

Links

- Lab index: `aws-labs/README.md`
- Deep dives: see `docs/README.md`

Note: Some topics (e.g., CloudTrail, SES) are referenced in docs but not built as full labs in this refresher.
