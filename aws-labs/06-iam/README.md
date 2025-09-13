# Lab 06 – IAM (ECS Roles)

## What Terraform Actually Creates (main.tf)

- `aws_iam_role.ecs_execution` with trust policy for `ecs-tasks.amazonaws.com`.
- Attachments:
  - `AmazonECSTaskExecutionRolePolicy` (pull from ECR, write logs, etc.).
  - Custom policy `aws_iam_policy.ecs_execution_extra` with conditionals:
    - Optional Secrets Manager read on `var.secrets_path_prefix` (default `/devops-refresher/staging/app/*`) when `var.grant_exec_role_secrets_read = true`.
    - Optional SSM read on `var.ssm_path_prefix/*` when `var.grant_exec_role_ssm_read = true`.
    - Optional `kms:Decrypt` when `var.kms_key_arn` is provided.
- `aws_iam_role.task` (the application’s runtime role) with trust for `ecs-tasks.amazonaws.com`.
- Conditional S3 least‑priv policy for `s3://<bucket>/app/*`:
  - When `var.s3_bucket_name` is provided, or auto‑detected from S3 lab remote state, create `aws_iam_policy.task_s3` and attach it to the task role.
- Optional SSM read for the task role when `var.grant_task_role_ssm_read = true` and `var.ssm_path_prefix` is set.
- ECS Exec support: attach `AmazonSSMManagedInstanceCore` to BOTH roles to enable SSM channels for `ecs exec`.
- Outputs: `execution_role_arn`, `task_role_arn`, `task_role_name`.

## CI/CD Roles (for Lab 15)

- CodeBuild role: `aws_iam_role.codebuild` with inline policy for logs and ECR push.
- CodePipeline role: `aws_iam_role.codepipeline` with inline policy:
  - `codestar-connections:UseConnection` on your GitHub connection ARN.
  - `codebuild:StartBuild`/`BatchGetBuilds` on CodeBuild projects in this account.
  - ECS deploy permissions (`ecs:RegisterTaskDefinition`, `ecs:UpdateService`, etc.) and `iam:PassRole`.
- Outputs:
  - `codebuild_role_arn`, `codepipeline_role_arn` (consumed by `aws-labs/15-cicd-ecs-pipeline`).

Note: S3 access to the pipeline artifacts bucket is granted via a bucket policy in Lab 15 to avoid coupling this lab to bucket naming.

### Migration Note: Adopting Existing CI/CD Roles

If the CI/CD roles were created elsewhere (e.g., in Lab 15 before this lab owned them), Terraform will fail here with `EntityAlreadyExists` when trying to create the same role names. Adopt the existing roles into this lab’s state using `terraform import` and then apply.

Symptoms:

- `EntityAlreadyExists: Role with name devops-refresher-codebuild-role already exists` (or the CodePipeline role)
- Lab 15 shows `Unsupported attribute` for `codebuild_role_arn` / `codepipeline_role_arn` when this lab hasn’t been applied yet.

Fix (copy/paste from aws-labs/06-iam):

```bash
terraform init
terraform import aws_iam_role.codebuild devops-refresher-codebuild-role
terraform import aws_iam_role_policy.codebuild_inline devops-refresher-codebuild-role:devops-refresher-codebuild
terraform import aws_iam_role.codepipeline devops-refresher-codepipeline-role
terraform import aws_iam_role_policy.codepipeline_inline devops-refresher-codepipeline-role:devops-refresher-codepipeline
terraform validate && terraform apply -auto-approve
```

Why this happens and how to avoid it:

- Decide IAM ownership up front. In these labs, Lab 06 owns CI/CD IAM; Lab 15 consumes ARNs via remote state. Apply Lab 06 before Lab 15.
- If you must prototype in Lab 15 first, import the created roles here before switching ownership.

## Permissions Checklist (Don’t Get Surprised)

- CodePipeline role (source/build/deploy):
  - `codestar-connections:UseConnection`: on the GitHub CodeConnections ARN used by the Source stage.
  - `codebuild:StartBuild`, `codebuild:BatchGetBuilds`: on the CodeBuild project(s) this pipeline triggers.
  - `ecs:RegisterTaskDefinition`, `ecs:UpdateService`, `ecs:DescribeTaskDefinition`, `ecs:DescribeServices`: to deploy to ECS.
  - `iam:PassRole`: for the ECS task execution/runtime roles that the service uses.
  - S3 artifacts access: provided via the bucket policy in Lab 15 (not here) — requires `s3:GetObject`, `s3:GetObjectVersion`, `s3:PutObject`, and `s3:GetBucketVersioning` on the artifacts bucket and prefix.

- CodeBuild role (build image + push to ECR):
  - CloudWatch Logs: `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`.
  - ECR push/pull: `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`, `ecr:PutImage`, `ecr:BatchGetImage`, `ecr:DescribeRepositories`.
  - S3 artifacts (if using CODEPIPELINE artifacts type, buildspec emits `imagedefinitions.json`): `s3:PutObject` on the artifacts bucket/prefix (granted by pipeline bucket policy in Lab 15).
  - Optional (only if build needs them): `ssm:GetParameter(s)`/`GetParametersByPath` for build-time parameters; KMS `Decrypt` if reading SecureStrings; Secrets Manager `GetSecretValue` if using BuildKit `--secret` sourced from env.

- S3 artifacts bucket policy (Lab 15):
  - Grants the CodePipeline role access to `s3:GetObject`, `s3:GetObjectVersion`, `s3:PutObject` on the bucket and prefix.
  - Grants `s3:GetBucketVersioning` on the bucket.

- Region alignment:
  - CodeConnections ARN region and CodePipeline region must match (here: `ap-southeast-2`).
  - ECR/ECS resources for this pipeline should be in the same region for simplicity.

- Where defined in this repo:
  - CodePipeline/CodeBuild roles + inline policies: `aws-labs/06-iam/main.tf:166` and `:215` (search for `codebuild` / `codepipeline`).
  - S3 bucket policy for pipeline artifacts: `aws-labs/15-cicd-ecs-pipeline/main.tf` (search for `aws_s3_bucket_policy.artifacts_access`).
  - Source connection ARN default: `aws-labs/06-iam/variables.tf:13` (`connection_arn`).

- Quick verification commands:
  - Inspect pipeline role inline policy: `aws iam get-role-policy --role-name devops-refresher-codepipeline-role --policy-name devops-refresher-codepipeline`.
  - Confirm UseConnection present and ARN matches: `grep -i UseConnection` output; check `Resource` equals your connection ARN.
  - Check CodeBuild can push: run a pipeline build and ensure it pushes both `:staging` and `:<git-sha>` to ECR without AccessDenied.

Key implementation details:

- Remote state is used to auto‑discover the S3 bucket from Lab 08 when `var.s3_bucket_name` is unset, so you don’t need to pass flags.
- Secrets prefix uses the form `arn:aws:secretsmanager:<region>:<acct>:secret:/devops-refresher/<env>/<service>/*` which matches Secrets Manager’s name pattern with a trailing `-*` generated by AWS. Using `.../*` in the resource string is correct here because the ARN target is a secret name prefix.
- SSM resources use the path prefix: `arn:aws:ssm:<region>:<acct>:parameter<var.ssm_path_prefix>/*`.

## Variables You Might Care About (variables.tf)

- `s3_bucket_name` (string, default ""): explicitly grant S3 app prefix access; otherwise auto‑detected via remote state.
- `grant_task_role_ssm_read` (bool, default false) + `ssm_path_prefix` (string): grant runtime SSM read to the task role.
- `grant_exec_role_ssm_read` (bool, default true): allow execution role to read SSM if you template SecureString values at task start.
- `grant_exec_role_secrets_read` (bool, default true) + `secrets_path_prefix` (string): allow execution role to read Secrets Manager for ECS `secrets`.
- `kms_key_arn` (string): optional CMK decrypt.

## Apply

```bash
cd aws-labs/06-iam
terraform init
terraform apply -auto-approve

# Optional overrides
# -var s3_bucket_name=...                  # override auto-detected bucket from Lab 08
# -var grant_task_role_ssm_read=true \\     # grant task SSM read if the app fetches SSM at runtime
#    -var ssm_path_prefix=/devops-refresher/staging/app
# -var grant_exec_role_secrets_read=false   # tighten if not using ECS secrets at startup
# -var grant_exec_role_ssm_read=false       # tighten if not pulling SSM via exec role
```

## How To Consume

- Pass `execution_role_arn` and `task_role_arn` into the ECS service/task definition.
- If you change IAM, force a new ECS deployment so new tasks pick up role changes:

```bash
aws --profile devops-sandbox --region ap-southeast-2 ecs update-service \
  --cluster devops-sandbox \
  --service app \
  --force-new-deployment
```

## ECS Exec requirements

- Both roles include `AmazonSSMManagedInstanceCore` in this lab.
- Ensure VPC has SSM interface endpoints (`ssm`, `ssmmessages`, `ec2messages`) or NAT egress.

## Verify

```bash
# Secrets path access example (adjust profile/region as needed)
aws secretsmanager get-secret-value \
  --profile devops-sandbox --region ap-southeast-2 \
  --secret-id /devops-refresher/staging/app/DB_PASS | jq .
```

## Cleanup

```bash
terraform destroy -auto-approve
```
