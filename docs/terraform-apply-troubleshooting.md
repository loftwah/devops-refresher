# Terraform Apply: Slow or Stuck — What To Do

This runbook helps decide when to wait, when to troubleshoot, and where to look when `terraform apply` seems slow or stuck, especially for AWS managed services like RDS and ElastiCache.

## Quick Rules of Thumb

- **Know typical durations**:
  - Security groups/subnet groups: seconds
  - ALB/NLB: 2–7 minutes
  - ElastiCache (Redis replication group): 5–15 minutes
  - RDS instance/cluster: 15–45+ minutes
- **When to wait**: Up to the typical time plus a small buffer (~2×). Example: Redis taking 10–15 minutes is normal.
- **When to dig in**: If the resource exceeds ~2× typical time, or AWS Console shows no progress/events for >10 minutes.
- **When to stop**: Only after inspecting AWS and confirming an error/blocked state. If you Ctrl‑C Terraform mid‑create, AWS may still finish provisioning; a re‑apply usually reconciles safely.

## Where to Look (AWS)

- **Service console**: Open the specific service and find the resource by name/ID.
  - ElastiCache → Redis → your replication group → check `Status` and the `Events` tab.
  - RDS → Databases → your instance/cluster → `Status` and `Events`.
- **Events first**: Errors like `InsufficientCacheClusterCapacity`, AZ/subnet issues, unsupported node type, parameter/auth problems will appear here.
- **Service Quotas**: Check for regional limits (e.g., ElastiCache node count per region) and recent limit changes.
- **AWS Health/Service status**: Rare, but regional capacity/service incidents can slow creates.

## What to Check (Networking/IAM)

- **Subnet group**: Subnets exist, in the right VPC, and in valid AZs for the service.
- **Security groups**: Creation is quick; misconfig won’t block service creation, but will affect connectivity later.
- **KMS permissions** (if encryption at rest custom key): Role has access to the CMK.
- **Region/profile**: Double‑check Terraform provider config and your `AWS_PROFILE`/`AWS_REGION`.

### Common ECS startup error: AccessDenied on Secrets Manager

- Symptom:
  - `AccessDeniedException: ... not authorized to perform secretsmanager:GetSecretValue on ... /devops-refresher/staging/app/DB_PASS-xxxxx`
- Cause:
  - Execution role policy used `...:secret:/devops-refresher/staging/app-*` which does not match nested names like `/devops-refresher/staging/app/DB_PASS-xxxxx`.
- Fix:
  - Update policy to `...:secret:/devops-refresher/staging/app/*` and apply IAM.
  - Ensure you are operating in the correct region and profile when forcing a new deployment:

```bash
aws ecs update-service \
  --region ap-southeast-2 \
  --profile devops-sandbox \
  --cluster devops-refresher-staging \
  --service app \
  --force-new-deployment
```

## Live Watch With AWS CLI

Use these during a long create to confirm backend status. Set your profile/region first (or export env vars):

```
aws elasticache describe-replication-groups \
  --replication-group-id <id> --region <region> \
  --query 'ReplicationGroups[0].[Status,MemberClusters,PendingModifiedValues]' --output table

aws elasticache describe-events \
  --source-type replication-group --source-identifier <id> \
  --region <region> --output table
```

## Terraform Knobs When It’s Slow

- **Resource timeouts**: Some resources support a `timeouts {}` block to tune create/update/delete windows. Example (ElastiCache replication group):

```hcl
resource "aws_elasticache_replication_group" "this" {
  # ...
  timeouts {
    create = "30m"
    update = "45m"
    delete = "45m"
  }
}
```

- **Provider/CLI logs**: For deeper debugging (very verbose):
  - `TF_LOG=DEBUG TF_LOG_PATH=terraform.log terraform apply`
  - Optionally: `TF_LOG_PROVIDER=DEBUG` (provider logs), or set AWS SDK logging via `AWS_*` env if needed.
- **State lock wait**: If you hit lock waits with remote state, increase `-lock-timeout=10m`.

## When to Cancel vs. Let It Finish

- **Let it finish** if:
  - AWS console shows `creating` with recent events (last 5–10 minutes), and total time is ≤ typical ×2.
- **Investigate/cancel** if:
  - No new events for >10 minutes and total time exceeds typical ×2.
  - Events show a hard error (capacity, permission, quota). In this case, cancel Terraform and fix the root cause before re‑apply.

After cancellation, check AWS for partially created resources. Terraform usually reconciles on the next `apply`, but you may need to delete failed resources manually if AWS left them in an error state.

## ElastiCache‑Specific Gotchas

- **Capacity/instance type**: Small/burstable types can be capacity‑constrained; try another AZ or node type if `InsufficientCacheClusterCapacity` occurs.
- **Subnet/AZ support**: Ensure your subnet group has subnets in supported AZs; for single‑node groups, at least one valid subnet is needed.
- **Encryption settings**: In‑transit and at‑rest encryption can extend create time slightly; CMK permissions must allow the service principal if using a custom key.
- **Auth tokens/parameter groups**: Invalid combinations can fail late; check events.

## Reference Durations (Guidance, not SLAs)

- SGs, rules, subnet groups: < 1 minute
- ALB/NLB: 2–7 minutes
- ElastiCache Redis (single primary): 5–15 minutes
- RDS (Postgres/MySQL): 15–45+ minutes

If you consistently see longer times, capture a few samples and add notes here for your region/account.
