# Lab 11: Parameter Store (SSM)

## Objective

Store non-secret configuration centrally in SSM Parameter Store and consume it from ECS and EKS.

## Decisions

- Use standard parameters for non-secrets (e.g., `APP_ENV`, `API_BASE_URL`).
- Use Secrets Manager for secrets (passwords, tokens). You can reference Secrets from ECS/EKS similarly.
- Naming: `/devops-refresher/staging/<service>/<key>`.

## Tasks

1. Create parameters in Terraform: `aws_ssm_parameter` with `type = "String"` and tags.
2. Grant read access to ECS task role or EKS service account (IRSA).
3. ECS: Load as environment variables using the task definition `secrets` (with SSM parameter ARNs) or init script that fetches via AWS SDK/CLI.
4. EKS: Use `envFrom` with `secrets-store-csi-driver` for Secrets, or mount via init containers; for simple strings, fetch at startup via SDK/Init.

## Examples

Terraform create parameter:

```hcl
resource "aws_ssm_parameter" "app_env" {
  name  = "/devops-refresher/staging/app/APP_ENV"
  type  = "String"
  value = "staging"
  tags  = merge(var.tags, { Name = "app-APP_ENV" })
}
```

ECS task definition secret (maps SSM to env):

```hcl
secrets = [
  {
    name      = "APP_ENV"
    valueFrom = aws_ssm_parameter.app_env.arn
  }
]
```

IAM policy snippet (ECS task role):

```hcl
data "aws_iam_policy_document" "ssm_read" {
  statement {
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/devops-refresher/staging/*"]
  }
}
```

## Acceptance Criteria

- Parameters exist in SSM with expected values and tags.
- ECS task or EKS pod has the environment variable(s) populated from SSM.
