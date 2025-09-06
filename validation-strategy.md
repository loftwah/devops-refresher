# Validation, Safety, and Operations

## Iterative Delivery

- Add/Change resources in small batches; run `plan` and inspect diffs.
- Validate in AWS after each apply: console, CLI, curl endpoints.
- Rollbacks: Tag releases, keep images immutable, revert task definition image/tag first.

## State Hygiene

- Separate state per environment (and optionally per domain: `network`, `ecs`, `cicd`).
- Lock with DynamoDB; never disable locking.
- Enable S3 versioning and MFA delete where appropriate.

## Imports & Drift

- Import legacy manually created resources; model only essential attributes first.
- Detect drift with periodic `plan` and optional AWS Config.

## Secrets Discipline

- Use SSM/Secrets Manager; mark TF variables `sensitive`.
- Pass secrets via task definition `secrets` not plain env vars.

## Checks & Tooling

- Pre-flight: `terraform fmt -check`, `validate`, `tflint` (optional), `tfsec` (optional).
- Visualize: `terraform graph | dot -Tsvg` for complex modules.

## Monitoring & Runbooks

- Minimum: ALB 5XX/Target 5XX alarms; ECS CPU/Mem alarms.
- Runbooks: Deploy failure, task crashloop, 5XX spikes, empty logs.
- Incident tips: Check target group health first, then ECS events, then app logs.

## Cost & Scale

- Right-size CPU/mem for tasks; scale to zero off-hours in staging.
- Lifecycle policies to clean old ECR images and CloudWatch logs.
