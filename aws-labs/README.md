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
- 17 – EKS Cluster (cluster, node group, OIDC, subnet tags)
- 18 – EKS ALB + ExternalDNS (IRSA roles + ACM)
- 19 – EKS External Secrets (IRSA + SecretStores)
- 20 – EKS App (Helm deploy with ESO + ALB)
- 21 – CI/CD for EKS (CodePipeline + CodeBuild Helm deploy)

## Backend and State

- All labs use a shared S3 backend for Terraform state with lockfile-based locking. Do not skip the backend during normal usage. See `aws-labs/00-backend.md` for guidance, troubleshooting, and why remote state is mandatory here.
- Regional model: Terraform state bucket is in `us-east-1`, while infrastructure (EKS/ECS/ALB/RDS/Redis/etc.) runs in `ap-southeast-2`.

## Kubernetes Assets

- All Kubernetes Helm values and manifests live under `aws-labs/kubernetes/`.
  - `aws-labs/kubernetes/helm/` – values files and demo-app chart.
  - `aws-labs/kubernetes/manifests/` – cluster-wide manifests (e.g., ClusterSecretStores, CSI patches).

## Validation

- Orchestrator: `aws-labs/scripts/validate-labs.sh` runs all available validators.
- Notable validators (can be run standalone):
  - `aws-labs/scripts/validate-eks-cluster.sh` – cluster ACTIVE, nodegroup ACTIVE, OIDC present, subnet tags.
  - `aws-labs/scripts/validate-eks-alb-externaldns.sh` – IRSA roles exist, ACM cert ISSUED.
  - `aws-labs/scripts/validate-eks-external-secrets.sh` – ESO role exists, SA annotation, SecretStores present.
  - `aws-labs/scripts/validate-eks-app.sh` – Deployment/Service/Ingress/ExternalSecret and HTTPS health.

## EKS Quickstart (17 → 20)

Zero‑flag flow to get the app live:

1. Lab 17 – EKS Cluster (once):

```
terraform -chdir=aws-labs/17-eks-cluster init
terraform -chdir=aws-labs/17-eks-cluster apply --auto-approve
```

2. Lab 18 – ALB + IAM + ACM (installs LBC by default):

```
terraform -chdir=aws-labs/18-eks-alb-externaldns apply --auto-approve
```

3. Lab 19 – External Secrets (optional now):

```
terraform -chdir=aws-labs/19-eks-external-secrets apply --auto-approve
```

4. Lab 20 – App deploy (Terraform):

```
terraform -chdir=aws-labs/20-eks-app init
terraform -chdir=aws-labs/20-eks-app apply --auto-approve
terraform -chdir=aws-labs/20-eks-app output -raw ingress_hostname
```

Kubernetes basics for verification: see `aws-labs/kubernetes/kubectl.md`.

## Optional/Extras

- CloudFront: `aws-labs/99-cloudfront.md`
- Fault labs: `aws-labs/99-fault-labs.md`

As of now, the core AWS lab flow ends at 20 (EKS App). If we add more, we will continue numbering sequentially. Note: Lab 21 adds a separate EKS pipeline to preserve ordering; both pipelines trigger from the same repo/branch.

## VPC Endpoints – Why Optional (but Recommended)?

- Without endpoints, workloads in private subnets can still reach AWS APIs (S3, ECR, SSM, etc.) via the NAT gateway and public Internet. Functionally, things work.
- We add endpoints to keep traffic on the AWS network, reduce NAT egress costs, enable stricter policies (e.g., `aws:sourceVpce`, Private DNS), and improve resilience when Internet egress is constrained.
- Lab 02 treats a minimal set (S3 Gateway, SSM/Exec, ECR, CloudWatch Logs) as part of the “staging baseline”, while others remain opt‑in.

## Maintenance

- Versions:
  - EKS: Prefer latest GA minor (>= 1.30). Set via `-var kubernetes_version` in `17-eks-cluster` and upgrade add‑ons/controllers afterward.
  - Controllers: Keep AWS Load Balancer Controller, ExternalDNS, and External Secrets Operator current via Helm.
  - App chart: Use immutable image tags and roll out via `helm upgrade`.
- Rotation:
  - Secrets (DB_PASS, APP_AUTH_SECRET): rotate in Secrets Manager; ESO syncs to K8s Secret on next refresh (`refreshInterval`, default 1h). Force re‑sync by editing the ExternalSecret or deleting the target Secret.
  - Parameters: update SSM; ESO will refresh; ECS tasks pick up on redeploy.
- Certificates:
  - ACM auto‑renews DNS‑validated certs as long as Route 53 records remain. ExternalDNS maintains records from Ingress.
- Cost & scaling:
  - Use VPC Endpoints to reduce NAT egress. Right‑size node groups; scale via `desired_size`/HPA as needed.
- Validation cadence:
  - Run `aws-labs/scripts/validate-labs.sh` after significant changes and on a schedule to catch drift or expiring resources.

## Secrets vs Parameters

- Non-secrets (like database host, port, user, and name) are published as Terraform outputs and written to SSM Parameter Store.
- Secrets (like database password) are created and managed in AWS Secrets Manager by the owning stack (for example, the RDS stack writes `/devops-refresher/{env}/{service}/DB_PASS`). Downstream stacks and workloads consume the secret via its ARN.
