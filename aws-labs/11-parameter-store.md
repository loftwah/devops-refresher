# Parameter Store (SSM)

## Objective

Centralize non-secret configuration in SSM Parameter Store and consume from ECS and EKS. Manage secrets in AWS Secrets Manager.

## Prerequisites

- For EKS: Secrets Store CSI Driver + AWS Provider installed in the cluster.
- For EKS: IRSA role for the app service account with read permissions to the SSM path and Secrets ARNs.
- For ECS: Task role with read permissions to the SSM path and Secrets ARNs.

## What Goes Where

- SSM (non-secrets, type String):
  - `APP_ENV`, `LOG_LEVEL`, `PORT`, `S3_BUCKET`, `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_NAME`, `DB_SSL`, `REDIS_HOST`, `REDIS_PORT`, `SELF_TEST_ON_BOOT`.
- Secrets Manager (secrets):
  - `DB_PASS`, `REDIS_PASS`.

Naming convention for both:

- `/devops-refresher/<env>/<service>/<key>` (example: `/devops-refresher/staging/app/DB_HOST`).

## Decisions

- Keep non-secrets in SSM as `String` for ease of review and tagging.
- Store secrets in Secrets Manager; reference from workloads with least privilege.
- ECS `secrets` field accepts Secrets Manager ARNs and SSM parameters of type SecureString. Since our non-secrets are plain `String`, fetch them at runtime or template them during deploy instead of mislabeling as SecureString.
- For EKS, prefer Secrets Store CSI Driver with AWS provider to sync SSM parameters and Secrets Manager secrets into Kubernetes Secrets (then `envFrom` them).

## Tasks

1. Create SSM parameters (Terraform)

```hcl
variable "env"     { type = string }
variable "service" { type = string }
variable "params"  {
  type = map(string)
  # example default for staging/app
  default = {
    APP_ENV          = "staging"
    LOG_LEVEL        = "info"
    PORT             = "3000"
    S3_BUCKET        = ""      # fill
    DB_HOST          = ""      # fill
    DB_PORT          = "5432"
    DB_USER          = ""      # fill
    DB_NAME          = ""      # fill
    DB_SSL           = "required"
    REDIS_HOST       = ""      # fill
    REDIS_PORT       = "6379"
    SELF_TEST_ON_BOOT= "false"
  }
}

resource "aws_ssm_parameter" "app" {
  for_each = var.params
  name     = "/devops-refresher/${var.env}/${var.service}/${each.key}"
  type     = "String"
  value    = each.value
  tags     = { App = "devops-refresher", Env = var.env, Service = var.service, Key = each.key }
}
```

2. Create Secrets (Terraform)

```hcl
variable "secret_values" {
  type = map(string)
  default = {
    DB_PASS    = ""  # fill in CI or via console
    REDIS_PASS = ""  # fill in CI or via console
  }
}

resource "aws_secretsmanager_secret" "app" {
  for_each = var.secret_values
  name     = "/devops-refresher/${var.env}/${var.service}/${each.key}"
}

resource "aws_secretsmanager_secret_version" "app" {
  for_each      = var.secret_values
  secret_id     = aws_secretsmanager_secret.app[each.key].id
  secret_string = each.value
}
```

3. Grant read access (IAM)

Attach to the ECS task role and/or EKS IRSA role for your app:

```hcl
data "aws_iam_policy_document" "ssm_read" {
  statement {
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/devops-refresher/${var.env}/${var.service}/*"]
  }
}

data "aws_iam_policy_document" "secrets_read" {
  statement {
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [for k in keys(var.secret_values) : "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:/devops-refresher/${var.env}/${var.service}/${k}-*"]
  }
}
```

## Consumption Patterns

ECS (Fargate/EC2):

- Non-secrets from SSM (String): fetch at container start via AWS CLI or SDK.

```bash
# example entrypoint snippet
PARAM_PATH="/devops-refresher/${APP_ENV}/app"
eval $(aws ssm get-parameters-by-path \
  --path "$PARAM_PATH" --with-decryption --query 'Parameters[*].{Name:Name,Value:Value}' \
  --output text | awk '{gsub(/.*\//, "", $1); printf("export %s=\"%s\"\n", $1, $2)}')
exec node server.js
```

- Secrets from Secrets Manager: map via task definition `secrets`.

```hcl
secrets = [
  { name = "DB_PASS",    valueFrom = aws_secretsmanager_secret.app["DB_PASS"].arn },
  { name = "REDIS_PASS", valueFrom = aws_secretsmanager_secret.app["REDIS_PASS"].arn }
]
```

EKS (IRSA + Secrets Store CSI Driver):

- Sync SSM parameters and Secrets into a Kubernetes Secret, then `envFrom` it.

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: app-config
  namespace: app
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "/devops-refresher/staging/app/DB_PASS"
        objectType: "secretsmanager"
      - objectName: "/devops-refresher/staging/app/REDIS_PASS"
        objectType: "secretsmanager"
      - objectName: "/devops-refresher/staging/app/APP_ENV"
        objectType: "ssmparameter"
      - objectName: "/devops-refresher/staging/app/DB_HOST"
        objectType: "ssmparameter"
        # ... add remaining non-secret keys
  secretObjects:
    - secretName: app-env
      type: Opaque
      data:
        - objectName: "/devops-refresher/staging/app/DB_PASS"
          key: DB_PASS
        - objectName: "/devops-refresher/staging/app/REDIS_PASS"
          key: REDIS_PASS
        - objectName: "/devops-refresher/staging/app/APP_ENV"
          key: APP_ENV
        - objectName: "/devops-refresher/staging/app/DB_HOST"
          key: DB_HOST
          # ... map remaining keys
```

Then in your Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: app
spec:
  template:
    spec:
      serviceAccountName: web
      volumes:
        - name: secrets-store
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: app-config
      containers:
        - name: app
          image: <account>.dkr.ecr.<region>.amazonaws.com/devops-refresher:latest
          envFrom:
            - secretRef:
                name: app-env
```

Ensure the service account used by the pod has IRSA permissions to read the above SSM path and Secrets ARNs.

## Inputs/Outputs

- Inputs (from other Terraform modules):
  - `S3_BUCKET` from S3 module (`module.s3.bucket_name`). See `aws-labs/08-s3.md:1`.
  - `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` from RDS module (`module.rds.db_host`, etc.). See `aws-labs/09-rds.md:1`.
  - `REDIS_HOST`, `REDIS_PORT` from ElastiCache module (`module.redis.redis_host`, etc.). See `aws-labs/10-elasticache-redis.md:1`.
- Static defaults (override as needed):
  - `APP_ENV`, `LOG_LEVEL`, `PORT`, `DB_SSL`, `SELF_TEST_ON_BOOT`.
- Secrets (populate securely in CI or via console):
  - `DB_PASS`, `REDIS_PASS`.

Example wiring of module outputs into SSM params:

```hcl
locals {
  dynamic_params = {
    S3_BUCKET  = module.s3.bucket_name
    DB_HOST    = module.rds.db_host
    DB_PORT    = tostring(module.rds.db_port)
    DB_USER    = module.rds.db_user
    DB_NAME    = module.rds.db_name
    REDIS_HOST = module.redis.redis_host
    REDIS_PORT = tostring(module.redis.redis_port)
  }

  static_params = {
    APP_ENV           = var.env
    LOG_LEVEL         = "info"
    PORT              = "3000"
    DB_SSL            = "required"
    SELF_TEST_ON_BOOT = "false"
  }
}

module "app_params" {
  # or inline resources using aws_ssm_parameter as above
  source  = "./modules/ssm-params"
  env     = var.env
  service = "app"
  params  = merge(local.static_params, local.dynamic_params)
}
```

## Acceptance Criteria

- SSM parameters exist with expected values and tags.
- Secrets exist in Secrets Manager and are scoped by env/service.
- ECS task and/or EKS pod has environment variables populated from SSM/Secrets Manager appropriately.
