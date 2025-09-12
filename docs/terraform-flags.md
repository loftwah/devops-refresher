# Terraform flags and when to use them

## Philosophy

- Prefer zero/low-flag applies. Most labs auto-read upstream values via `terraform_remote_state` and use sensible defaults.
- Use `-var` flags only when overriding defaults or running a lab in isolation.

## Common flags by lab

### 06 – IAM

- Optional: `-var s3_bucket_name=...`
  - When to use: override auto-detected S3 bucket from Lab 08. Not needed if Lab 08 exists.
- Optional: `-var grant_task_role_ssm_read=true -var ssm_path_prefix=/devops-refresher/staging/app`
  - When to use: if your app reads SSM at runtime. Otherwise skip.

### 08 – S3

- Optional: `-var bucket_name=my-explicit-name`
  - When to use: deterministic bucket names. Otherwise auto-generated with a suffix.

### 09 – RDS

- Required on first apply: `-var db_name -var db_user -var db_password`
  - When to use: always (initial creation). Consider tfvars for convenience.

### 10 – ElastiCache Redis

- Required: `-var vpc_id -var private_subnet_ids -var app_sg_id`
  - When to use: if running in isolation. When running sequentially, you can source from prior labs.

### 11 – Parameter Store

- Minimal apply: `terraform apply -auto-approve`
  - Reads S3, RDS, Redis from remote state.
- Overrides: `-var env=... -var service=... -var s3_bucket=... -var db_host=...` etc.
  - When to use: non-default env/service or custom values.
- Secrets: `-var 'secret_values={ APP_AUTH_SECRET="..." }'`
  - When to use: set/rotate app auth secret via Terraform.

### 12 – ALB

- Required: `-var vpc_id -var public_subnet_ids -var alb_sg_id -var certificate_domain_name -var hosted_zone_name -var record_name`
  - When to use: initial create; values often come from prior labs or env.

### 14 – ECS Service

- Minimal apply: most inputs are auto-detected from remote state.
- Optional direct wiring: `-var cluster_arn -var subnet_ids -var security_group_ids -var target_group_arn -var execution_role_arn -var task_role_arn`
  - When to use: if running ECS in isolation or with non-standard wiring.
- Image: `-var image=<account>.dkr.ecr.<region>.amazonaws.com/devops-refresher:staging`
  - When to use: override default `:staging` tag derived from Lab 03.
- Env/secrets auto-load:
  - `-var ssm_path_prefix=/devops-refresher/staging/app`
  - `-var auto_load_env_from_ssm=true -var auto_load_secrets_from_sm=true`
  - `-var 'secret_keys=["DB_PASS","APP_AUTH_SECRET"]'`

## Patterns and tips

- Use `*.auto.tfvars` to avoid long command lines.
- Each lab’s README lists minimal and override examples; this page centralizes the “when” and “why”.
- Default region: ap-southeast-2. Default ECS cluster: devops-sandbox.
