# Lab 14 – ECS Service (App)

## Objectives

- Deploy the app on ECS Fargate, attach to the ALB target group, and use existing IAM roles.

## Prerequisites

- Lab 13 ECS Cluster: `cluster_arn`.
- Lab 01 VPC: `private_subnet_ids`.
- Lab 07 Security Groups: `app_sg_id`.
- Lab 12 ALB: `tg_arn`.
- Lab 06 IAM: `execution_role_arn`, `task_role_arn`.
  - Ensure these include `AmazonSSMManagedInstanceCore` for ECS Exec.

## Apply

```bash
cd aws-labs/14-ecs-service
terraform init
terraform apply -auto-approve

# Optional overrides (if running in isolation or customizing wiring)
# -var cluster_arn=...
# -var 'subnet_ids=["subnet-...","subnet-..."]'
# -var 'security_group_ids=["sg-..."]'
# -var target_group_arn=...
# -var execution_role_arn=... -var task_role_arn=...
# -var image=<account>.dkr.ecr.<region>.amazonaws.com/devops-refresher:staging
# -var container_port=3000 -var desired_count=1
# -var 'secret_keys=["DB_PASS","APP_AUTH_SECRET"]'
# # Optional: disable auto-loading from SSM/Secrets and set explicit env/secrets
# -var auto_load_env_from_ssm=false -var auto_load_secrets_from_sm=false \
# -var 'environment=[{name="APP_ENV",value="staging"}]' \
# -var 'secrets=[{name="DB_PASS",valueFrom="arn:aws:secretsmanager:...:secret:/devops-refresher/staging/app/DB_PASS-xxxx"}]'
```

To map secrets (DB_PASS, REDIS_PASS, APP_AUTH_SECRET):

```bash
-var 'secrets=[{name="DB_PASS",valueFrom="arn:aws:secretsmanager:...:secret:/devops-refresher/staging/app/DB_PASS-xxxx"},{name="REDIS_PASS",valueFrom="arn:aws:secretsmanager:...:secret:/devops-refresher/staging/app/REDIS_PASS-xxxx"},{name="APP_AUTH_SECRET",valueFrom="arn:aws:secretsmanager:...:secret:/devops-refresher/staging/app/APP_AUTH_SECRET-xxxx"}]'
```

## Outputs

- `service_name`, `task_definition_arn`.

## Image tag requirements and troubleshooting

- The service defaults to using the ECR repository URL from Lab 03 with the `:staging` tag when `-var image` is not provided.
- Ensure your build process pushes at least two tags for the app image:
  - An immutable tag, e.g., the short git SHA.
  - An environment tag used by ECS, e.g., `staging`.
- Example build/push flow:

```bash
AWS_PROFILE=devops-sandbox AWS_REGION=ap-southeast-2 \
  ./build-and-push.sh   # tags and pushes :<sha> and :staging

# Verify the tag exists
aws ecr describe-images \
  --repository-name demo-node-app \
  --query 'imageDetails[].imageTags' \
  --region ap-southeast-2 --profile devops-sandbox
```

Common error

- `CannotPullContainerError: ... demo-node-app:staging: not found` means `:staging` was not pushed to ECR. Push the tag (see above) and re-apply the service.

## ECS Exec (Built-in)

- This lab enables ECS Exec via `enable_execute_command = true` in `main.tf`.
- IAM requirements are fulfilled by Lab 06 (IAM): both the task role and execution role have `AmazonSSMManagedInstanceCore` attached.
- Network requirements are fulfilled by Lab 02 (VPC Endpoints): interface endpoints for `ssm`, `ssmmessages`, and `ec2messages` are created with Private DNS.
- Container image must include a shell (`/bin/sh` or `/bin/bash`). Alpine has `/bin/sh` by default.

See `docs/ecs-exec.md` for full details and validation steps.

## What Terraform Actually Creates (main.tf)

- Auto-discovers cluster, subnets, SGs, ALB target group, IAM roles, and ECR repository URL via remote state when you don’t pass variables.
- `aws_ecs_task_definition.app`:
  - Fargate task with CPU/memory from variables, runtime platform set to `LINUX/X86_64`.
  - One container named after `var.service_name` with:
    - Image: defaults to `<repo>:staging` from ECR lab.
    - Logs to CloudWatch using `awslogs` with `var.log_group_name` and `var.region`.
    - Health check that hits `http://localhost:${var.container_port}/healthz`.
    - Environment and secrets composed from explicit vars plus optional auto-load from SSM and Secrets Manager under `var.ssm_path_prefix`.
- `aws_ecs_service.app`:
  - Fargate launch type, desired count, ECS Exec enabled, grace period set.
  - Awsvpc networking in private subnets with `assign_public_ip=false` and app SG.
  - Load balancer attachment to the ALB target group.

## Variables (variables.tf)

- Wiring (all optional due to remote state): `cluster_arn`, `subnet_ids`, `security_group_ids`, `target_group_arn`, `execution_role_arn`, `task_role_arn`.
- Container: `image`, `container_port`, `cpu`, `memory`, `service_name`, `desired_count`.
- Logs: `log_group_name` (defaults to `/aws/ecs/devops-refresher-staging`), `region` (required for awslogs; see note below).
- Config sourcing: `ssm_path_prefix` (default `/devops-refresher/staging/app`), `auto_load_env_from_ssm` (default true), `auto_load_secrets_from_sm` (default true), `secret_keys` (default `["DB_PASS","APP_AUTH_SECRET"]`).
- Manual overrides: `environment` (list of name/value), `secrets` (list of name/valueFrom).

Note: If `var.region` is not defined in your variables file, set it explicitly or ensure a default exists; the awslogs driver requires the region.

## Cleanup

```bash
terraform destroy -auto-approve
```

## Self-test endpoint

- After deployment, you can run the built-in end-to-end self-test which exercises S3, Postgres, and Redis:

```
https://demo-node-app-ecs.aws.deanlofts.xyz/selftest?token=<APP_AUTH_SECRET>
```

- Expected JSON output shape when all checks pass:

```json
{
  "s3": { "ok": true, "bucket": "<bucket>", "key": "app/selftest-<ts>.txt" },
  "db": { "ok": true, "id": "<uuid>" },
  "redis": { "ok": true, "key": "selftest:<uuid>" }
}
```

- If authorization is required, use either:
  - Query string: `?token=<APP_AUTH_SECRET>`
  - Header: `Authorization: Bearer <APP_AUTH_SECRET>`
