# Labs Overview

Hands-on exercises to build an ECS/EKS staging stack step-by-step. Each lab includes objectives, tasks, acceptance criteria, and cleanup notes. Use your own AWS account.

Suggested order (high-level):

- 00 – Backend (state bucket)
- 01 – VPC (subnets, NAT)
- 02 – VPC Endpoints (optional but recommended)
- 03 – ECR (repo, lifecycle)
- 05 – DNS (subdomain)
- 06 – IAM (task exec + task role)
- 07 – Security Groups (shared ALB + app)
- 08 – S3 (app bucket)
- 09 – RDS (Postgres)
- 10 – ElastiCache (Redis)
- 11 – Parameter Store (populate last, after above outputs)
- 12 – ALB (listener/target-group)
- 13 – ECS Cluster (shared)
- 14 – ECS Service (app)
- 15 – CI/CD: CodePipeline to ECS
- 16 – Observability (CloudWatch logs, metrics, alarms, dashboard)

## Backend and State

- All labs use a shared S3 backend for Terraform state with lockfile-based locking. Do not skip the backend during normal usage. See `aws-labs/00-backend.md` for guidance, troubleshooting, and why remote state is mandatory here.

## Secrets vs Parameters

- Non-secrets (like database host, port, user, and name) are published as Terraform outputs and written to SSM Parameter Store.
- Secrets (like database password) are created and managed in AWS Secrets Manager by the owning stack (for example, the RDS stack writes `/devops-refresher/{env}/{service}/DB_PASS`). Downstream stacks and workloads consume the secret via its ARN.
