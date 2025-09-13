# ADR-002: Secrets and Configuration (ECS/EKS)

## Context

- The app needs non-secret config (DB host/port, Redis host/port, S3 bucket) and secrets (DB/Redis passwords).
- We deploy on ECS (primary) and may also run on EKS.

## Decision

- Non-secrets live in SSM Parameter Store (String). Secrets live in Secrets Manager.
- ECS:
  - Map secrets using ECS task definition `secrets` (execution role reads Secrets Manager/KMS).
  - Load non-secrets at startup from SSM using a small script, or template values at deploy time.
- EKS:
  - Use Secrets Store CSI Driver to sync Secrets Manager + SSM parameters into a Kubernetes Secret; `envFrom` in Deployments.

## Rationale

- Principle of least privilege and separation of concerns: secrets vs. config.
- Avoids baking secrets into task definitions or container images; supports rotation.
- Works across ECS and EKS with consistent naming: `/devops-refresher/<env>/app/<KEY>`.

## Implementation Notes

- SSM path: `/devops-refresher/staging/app` with keys like `DB_HOST`, `DB_PORT`, `S3_BUCKET`.
- Secrets Manager names: `/devops-refresher/staging/app/DB_PASS`, `/.../REDIS_PASS`.
- IAM:
  - Execution role: `AmazonECSTaskExecutionRolePolicy` + read `ssm:GetParameters*` and `secretsmanager:GetSecretValue` for the above paths; KMS `Decrypt` if using CMKs.
  - Task role: grant only what the app calls directly (e.g., S3 bucket access; SSM read only if the app itself fetches SSM at runtime).
- Script: `aws-labs/scripts/fetch-ssm-env.sh` can export SSM params by path.

## Alternatives Considered

- All secrets and config in Secrets Manager (more cost; overuse of SecureString semantics for non-secrets).
- ConfigMaps in EKS and plaintext env in ECS (drifts from AWS secret stores; harder rotation).

## Checklist

- [x] SSM params populated from S3/RDS/Redis outputs
- [x] Secrets created in Secrets Manager (values set out of band or via CI)
- [x] Execution role can read Secrets/SSM (+KMS decrypt if needed)
- [x] Task role has least-priv S3 (+SSM if app fetches at runtime)
