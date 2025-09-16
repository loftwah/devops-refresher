# Lab 21 – Blueprint: Production-Grade Structure and Pipelines (Walkthrough)

## Objective

- Tie together what we built in labs 00–20 and map it to a production-grade repo and pipeline structure.
- Show the “correct way” using our actual labs, with links to resources and how we used them.
- Provide a concise validation checklist and references for deeper theory.

For the full theory and rationale, see: `aws-labs/21-blueprint-ideal-structure/README.md`

## What We Built (by area)

- Backend & State:
  - `aws-labs/00-backend.md` – Remote S3 backend in `us-east-1` for all Terraform state.
  - State is environment-scoped; downstream labs read upstream state outputs instead of re-defining resources.

- Shared Foundation:
  - `aws-labs/01-vpc.md` – VPC, subnets, routing, NAT.
  - `aws-labs/02-vpc-endpoints.md` – Private access to AWS APIs (recommended to reduce NAT egress and improve resilience).
  - `aws-labs/05-dns-route53.md` – Subdomain in Route 53 for app ingress.
  - `aws-labs/06-iam.md` – Central IAM roles (task exec, task roles, pipeline roles).
  - `aws-labs/07-security-groups.md` – Shared ALB and app security groups.
  - `aws-labs/08-s3.md` – App bucket for assets/attachments.
  - `aws-labs/09-rds.md` – Postgres database; writes secret to Secrets Manager.
  - `aws-labs/10-elasticache-redis.md` – Redis cache.
  - `aws-labs/11-parameter-store.md` – Runtime configuration (non-secrets) in SSM Parameter Store.
  - `aws-labs/12-alb.md` – ALB listener/target-group for ECS path.

- Platform Runtimes:
  - ECS:
    - `aws-labs/13-ecs-cluster.md` – Shared ECS cluster.
    - `aws-labs/14-ecs-service.md` – App service on ECS.
    - `aws-labs/15-cicd-ecs-pipeline.md` – CI/CD building once and deploying to ECS.
  - EKS:
    - `aws-labs/17-eks-cluster.md` – EKS cluster, managed node group, OIDC, subnet tags.
    - `aws-labs/18-eks-alb-externaldns.md` – IRSA roles + install AWS Load Balancer Controller and ExternalDNS; ACM cert.
    - `aws-labs/19-eks-app.md` – Deploy app via Terraform + Helm chart.
    - `aws-labs/20-cicd-eks-pipeline/README.md` – CI/CD deploy to EKS via CodePipeline/CodeBuild running Helm.

- Observability:
  - `aws-labs/16-observability.md` – CloudWatch logs/metrics/alarms/dashboard.
  - `aws-labs/22-observability-otel/README.md` – OpenTelemetry collector + logs (optional).

## How This Fits the Blueprint

Blueprint theory and patterns: `aws-labs/21-blueprint-ideal-structure/README.md`

- Modules vs Stacks vs Environments:
  - Our labs model “stacks” that consume upstream state and expose outputs for downstream labs.
  - Environment overlays hold backend config and env-specific variables.
  - Reusable logic lives in Terraform modules when shared across stacks.

- State model:
  - One S3 bucket holds all environment states, keyed per env/stack (e.g., `staging/shared/vpc/terraform.tfstate`).
  - Downstream stacks read remote state for references (VPC IDs, SGs, RDS endpoints, cert ARNs).

- Runtime config & secrets:
  - Non-secrets in SSM Parameter Store; secrets in Secrets Manager (created by the owning stack, e.g., RDS).
  - ECS tasks read params/secrets at runtime; EKS consumes via Helm values and/or External Secrets Operator (optional).
  - Helm values: `aws-labs/kubernetes/helm/demo-app/values.yml` sets immutable image digest, `buildVersion`, and `DEPLOY_PLATFORM=eks`.

- Security & networking:
  - Centralized Security Groups for ALB and apps; EKS app SG ingress to RDS/Redis managed in Terraform (no SGP required).
  - VPC Endpoints keep control plane traffic private and reduce NAT egress.

## Pipelines: What We Did vs Ideal

- Built once, deployed to both runtimes:
  - ECS pipeline: `aws-labs/15-cicd-ecs-pipeline.md`
  - EKS pipeline: `aws-labs/20-cicd-eks-pipeline/README.md`
  - Both trigger from the same repo/branch. The EKS pipeline waits for the ECR tag, resolves the image digest, and deploys with `--atomic --wait`.

- Immutable deployments in EKS:
  - Use image digest and a `buildVersion` pod-template annotation to force rollouts, avoiding mutable-tag pitfalls.
  - Values source: `aws-labs/kubernetes/helm/demo-app/values.yml`

- Ideal consolidation:
  - The blueprint favors a single pipeline that builds once and deploys to ECS and EKS in sequence. We kept two pipelines to preserve lab ordering, but the pattern and roles support unification.

## Resources We Used (and how)

- AWS Services: VPC, ECS, EKS, ECR, ALB/ELBv2, Route 53, ACM, S3, RDS, ElastiCache, CloudWatch, IAM, SSM Parameter Store, Secrets Manager, CodePipeline, CodeBuild.
- In-repo assets:
  - Helm chart and values: `aws-labs/kubernetes/helm/demo-app`
  - Validators: `aws-labs/scripts/validate-*.sh` (per-lab and orchestrator).
  - EKS deploy helper: `aws-labs/scripts/eks-deploy-app.sh` (mirrors CodeBuild behavior).
  - AWS auth mapper: `aws-labs/scripts/eks-map-aws-auth.sh` (grants cluster RBAC to CodeBuild role).

## Validation Checklist

- End-to-end validators:
  - `aws-labs/scripts/validate-labs.sh` – orchestrates all checks.

- Spot checks by area:
  - Backend/state: `aws-labs/scripts/validate-backend.sh`
  - VPC & endpoints: `aws-labs/scripts/validate-vpc.sh`, `aws-labs/scripts/validate-vpc-endpoints.sh`
  - IAM & SGs: `aws-labs/scripts/validate-iam.sh`, `aws-labs/scripts/validate-security-groups.sh`
  - ECS path: `aws-labs/scripts/verify-ecs.sh`, `aws-labs/scripts/validate-cicd.sh`
  - EKS platform: `aws-labs/scripts/validate-eks-cluster.sh`, `aws-labs/scripts/validate-eks-alb-externaldns.sh`
  - EKS app: `aws-labs/scripts/validate-eks-app.sh`, `aws-labs/scripts/validate-eks-cicd.sh`
  - Observability: `aws-labs/scripts/validate-observability.sh`

## Deliverables in This Repo

- Theory blueprint: `aws-labs/21-blueprint-ideal-structure/README.md`
- Numbered walkthrough (this file): `aws-labs/21-blueprint-ideal-structure.md`
- CI/CD for EKS: `aws-labs/20-cicd-eks-pipeline/README.md`
- Helm chart and values: `aws-labs/kubernetes/helm/demo-app`

## Next Steps

- If desired, consolidate ECS and EKS deploys into a single “build-once, deploy-twice” pipeline (keeps the same roles and image immutability rules).
- Consider extracting shared Terraform into `modules/` and promoting this repo as a reference for “stacks” and “environments” per the blueprint.
