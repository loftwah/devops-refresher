# Lab 21 – Blueprint: Production-Grade Structure and Pipelines

This is the practical, copy/paste walkthrough that proves the blueprint using the working labs in this repo. It shows exactly how we achieved each goal with commands, file paths, and validators. Deep rationale remains below in the theory sections.

## Hands-on Walkthrough (copy/paste)

Prereqs:

- AWS profile and region set (examples use `devops-sandbox` and `ap-southeast-2`).
- CodeConnections GitHub connection ready (same one used in Lab 15/20 pipelines).
- S3 backend initialized via Lab 00.

Tip: Validators live in `aws-labs/scripts`. You can run the orchestrator anytime: `aws-labs/scripts/validate-labs.sh`.

1. Backend (00)

```
terraform -chdir=aws-labs/00-backend-bootstrap init
terraform -chdir=aws-labs/00-backend-bootstrap apply -auto-approve
aws-labs/scripts/validate-backend.sh
```

2. Shared foundation (01→12)

```
terraform -chdir=aws-labs/01-vpc apply -auto-approve
terraform -chdir=aws-labs/02-vpc-endpoints apply -auto-approve   # optional but recommended
terraform -chdir=aws-labs/03-ecr apply -auto-approve
terraform -chdir=aws-labs/05-dns-route53 apply -auto-approve
terraform -chdir=aws-labs/06-iam apply -auto-approve
terraform -chdir=aws-labs/07-security-groups apply -auto-approve
terraform -chdir=aws-labs/08-s3 apply -auto-approve
terraform -chdir=aws-labs/09-rds apply -auto-approve             # optional for demo features
terraform -chdir=aws-labs/10-elasticache-redis apply -auto-approve # optional for demo features
terraform -chdir=aws-labs/11-parameter-store apply -auto-approve
terraform -chdir=aws-labs/12-alb apply -auto-approve              # ECS path ALB

# Spot checks
aws-labs/scripts/validate-vpc.sh
aws-labs/scripts/validate-vpc-endpoints.sh      # if applied
aws-labs/scripts/validate-iam.sh
aws-labs/scripts/validate-security-groups.sh
```

3. ECS runtime (13→14)

```
terraform -chdir=aws-labs/13-ecs-cluster apply -auto-approve
terraform -chdir=aws-labs/14-ecs-service apply -auto-approve
aws-labs/scripts/verify-ecs.sh
```

4. EKS runtime (17→19)

```
terraform -chdir=aws-labs/17-eks-cluster apply -auto-approve
aws-labs/scripts/validate-eks-cluster.sh

terraform -chdir=aws-labs/18-eks-alb-externaldns apply -auto-approve \
  -var oidc_provider_arn=$(cd aws-labs/17-eks-cluster && terraform output -raw oidc_provider_arn)
aws-labs/scripts/validate-eks-alb-externaldns.sh

# Map the CodeBuild role (from IAM lab) into cluster RBAC
aws-labs/scripts/eks-map-aws-auth.sh \
  $(cd aws-labs/06-iam && terraform output -raw codebuild_role_arn) \
  $(cd aws-labs/17-eks-cluster && terraform output -raw cluster_name) \
  ap-southeast-2 system:masters

# Deploy the app to EKS via Terraform (uses in-repo Helm chart/values)
terraform -chdir=aws-labs/19-eks-app init
terraform -chdir=aws-labs/19-eks-app apply -auto-approve
terraform -chdir=aws-labs/19-eks-app output -raw ingress_hostname
aws-labs/scripts/validate-eks-app.sh
```

5. CI/CD pipelines (15 for ECS, 20 for EKS)

```
# ECS pipeline
terraform -chdir=aws-labs/15-cicd-ecs-pipeline apply -auto-approve

# EKS pipeline (Helm deploy from CodeBuild; waits for ECR image tag)
terraform -chdir=aws-labs/20-cicd-eks-pipeline apply -auto-approve
```

Notes:

- EKS pipeline: see `aws-labs/20-cicd-eks-pipeline/README.md` for how it waits for the ECR tag, resolves the image digest, and runs `helm upgrade --install` with `--wait --atomic` and `buildVersion`.
- Manual EKS deploy (for ad‑hoc testing): `PROFILE=devops-sandbox AWS_REGION=ap-southeast-2 aws-labs/scripts/eks-deploy-app.sh`.

6. One build → two deploys (prove it)

Push a commit to the app repo (used by the pipelines). Both pipelines trigger from the same repo/branch:

- ECS pipeline deploys to ECS using the `<git-sha>` tag.
- EKS pipeline waits for the ECR tag, reads the immutable digest, and deploys to EKS with `image.digest` + `buildVersion`.

Validate:

```
aws-labs/scripts/validate-cicd.sh
aws-labs/scripts/validate-eks-cicd.sh
aws-labs/scripts/verify-ecs.sh
aws-labs/scripts/validate-eks-app.sh
```

Where we used things (exact files):

- Helm chart/values used by EKS: `aws-labs/kubernetes/helm/demo-app/values.yml` (sets `DEPLOY_PLATFORM=eks`, `pullPolicy=Always`, accepts `image.digest` + `buildVersion`).
- EKS pipeline buildspec and Terraform: `aws-labs/20-cicd-eks-pipeline/*`.
- IAM roles for CodeBuild/CodePipeline: `aws-labs/06-iam/*` (exported via remote state and mapped via `eks-map-aws-auth.sh`).
- Validators and helpers: `aws-labs/scripts/*` (used throughout in this walkthrough).

---

This lab is the clean, production-grade design we planned: a single build producing one immutable image that deploys to ECS and EKS, with clear separation of modules vs stacks, environment overlays, and centralized IAM. It does not modify existing labs; those remain as incremental concept labs. Use this when you want a cohesive, shippable structure.

---

## Autoscaling, Sizing, and Capacity Planning (theory, actionable)

Scope: the demo app is stateless and currently runs as a single task/pod. Below is the recommended approach to right‑size, set requests/limits, and configure autoscaling in both ECS and EKS. No code here — use this to guide values and policies when you harden the app.

- What: Establish SLOs and load profile
  - Define latency/error SLOs (e.g., p95 < 200ms, error rate < 1%) and expected RPS patterns (steady vs bursty).
  - Decide scale bounds (min/max tasks/pods) and disruption budget (max unavailable during deploys).

- Why: Baseline and right‑size the container
  - Load test incrementally to find the “knee” where latency spikes. Record CPU %, memory RSS, and throughput at that point.
  - Start with conservative sizing, then tighten:
    - EKS: set `resources.requests` to typical steady‑state usage and `resources.limits` to 1.5–2x bursts.
    - ECS: set `cpu` (units) and `memory` (soft) to steady‑state, with `memoryReservation`/`memory` or hard limit allowing short spikes.
  - Use observations to pick starting points (example for Node.js demo): 200–500m CPU, 256–512Mi memory per replica.

- How (EKS): autoscaling stack
  - Horizontal Pod Autoscaler (HPA): target 60–70% CPU and/or custom metric (RPS per pod or ALB TargetResponseTime).
  - Cluster Autoscaler (CA): ensure node groups allow headroom and scale out quickly (scale‑up delay ≤ 1 min) with max nodes sized for burst.
  - PodDisruptionBudget (PDB): maintain at least 1 replica during voluntary disruptions; set min available accordingly.
  - Topology: spread replicas across AZs via topologySpreadConstraints or anti‑affinity to improve resilience.

- How (ECS): autoscaling stack
  - Service Auto Scaling (SAS): target tracking on 60–70% CPU or Memory; optionally step scaling on ALB `RequestCountPerTarget` or custom metrics.
  - Capacity provider: if EC2, use ASG capacity provider with managed scaling; if Fargate, ensure service min/max tasks fit budget and SLOs.
  - Deployment safety: enable deployment circuit breaker and rollback on failure; keep minHealthyPercent ≥ 100 for no downtime.

- When: choose the right signal for scaling
  - CPU/memory are easy but may lag user experience. Prefer a user‑centric metric for scale‑out (e.g., ALB target response time p95, or queue depth/time) with a CPU floor as a backstop.
  - Queue‑driven (workers): scale on backlog per consumer target (messages per replica) and time‑to‑empty.

- Validate and iterate
  - After each change, rerun load tests, check p95 latency, saturation (CPU > 80%, memory > 90%), and rollout stability.
  - Watch costs: scaling policies that oscillate or keep replicas hot can be tuned with cooldowns and less aggressive targets.

Deliverables to update (no code here, just where you’d express it):

- EKS: Helm values `resources.requests/limits`, HPA spec, PDB, topology spread.
- ECS: Task definition CPU/memory, service autoscaling policies, deployment configuration, capacity provider.

Examples (real‑world, aligned to this repo):

- EKS web API (demo‑app):
  - What: 2 replicas min, up to 6 under burst; 300m CPU/256Mi requests, 600m/512Mi limits.
  - Why: p95 latency held under 200ms up to ~80 RPS per pod in load test; CPU saturates before memory.
  - When: Scale out at 65% CPU OR ALB `TargetResponseTime` > 150ms for 2 minutes; scale in after 10 minutes under 40% CPU and sub‑100ms RT.
  - How: Set HPA on CPU and external metric; ensure CA has headroom (max nodes +1 above expected peak); add PDB minAvailable=1.

- ECS service (ALB‑fronted):
  - What: Fargate tasks with 0.5 vCPU, 512Mi each; min 2, max 6.
  - Why: Matches observed container profile and desired N+1 redundancy.
  - When: Target tracking at 65% CPU; step scale out +1 task when ALB `RequestCountPerTarget` > 150 for 2 minutes; cool down 5 minutes.
  - How: Configure Service Auto Scaling with target tracking and one step policy; enable deployment circuit breaker.

Tuning checklist (use to drive values):

- Inputs: expected peak/average RPS, p95 latency target, acceptable error rate, burst duration, rollout disruption budget.
- Baseline: run a short load test; capture CPU%, memory RSS, throughput at latency knee.
- Requests/limits: set requests to steady‑state; limits at 1.5–2x; avoid limit‑throttling long GC pauses.
- Scaling signals: pick user‑centric metric (p95 RT or queue depth) + CPU floor; set sensible cooldowns.
- Bounds: set min replicas/tasks for N+1 AZ redundancy; cap max to budget and cluster capacity.
- Resilience: add PDB (EKS), topology spread/anti‑affinity across AZs; ECS minHealthyPercent ≥ 100 for zero‑downtime.
- Validation: re‑test after changes; confirm rollout stability, no oscillation, and cost within target.
- Observability: dashboard CPU/mem, RPS, p95 latency, error rate; alarms on saturation and SLO breaches.

---

## S3 Data Management, Macie, and SOC 2 (theory, actionable)

Goal: define how we store, protect, classify, and retain app objects in S3 to meet security and compliance expectations without turning this into a separate lab.

- What: Bucket design and access
  - One bucket per environment or a single bucket with env prefixes: `/dev`, `/stg`, `/prod`.
  - Enable Block Public Access and object ownership (bucket owner enforced); disallow ACLs.
  - Default encryption with SSE‑KMS using a project CMK; restrict KMS key to app roles; rotate per policy.
  - Access via IAM policies using least privilege principals (app task role, limited admin role). Prefer presigned URLs over wide write permissions.

- Why: Data lifecycle and cost controls
  - Enable versioning for recovery from deletes/overwrites.
  - Lifecycle policies: transition non‑current/old objects (e.g., 30d → Standard‑IA, 90d → Glacier Instant/Deep Archive), expire incomplete multipart uploads (7d), and optionally expire temporary objects.
  - Replication (SRR/CRR): replicate to another region/account for DR or compliance; include replica KMS settings and metrics.
  - Inventory and Storage Lens: schedule daily inventory reports for auditing; use Storage Lens for usage trends and anomaly detection.

- How: Visibility and detection
  - CloudTrail data events for S3 Put/Get/Delete on sensitive buckets; aggregate in a security account.
  - CloudWatch alarms on unusual activity (delete spikes, denied actions, public policy change attempts).
  - AWS Config rules and Security Hub controls to flag public access, missing encryption, and missing versioning.

- How: Macie for data classification
  - Scope: target buckets with user‑generated or sensitive data; exclude ephemeral buckets.
  - Jobs: scheduled sensitive data discovery (weekly/monthly) using managed and custom classifiers for your data types.
  - Findings: route to Security Hub; triage workflow to remediate (tighten policies, quarantine prefixes, rotate credentials).
  - Cost management: sample or scope to active prefixes; start narrow and expand.

- When: SOC 2 alignment (selected practices)
  - Logical access: least privilege for S3 and KMS; periodic access reviews; break‑glass role with MFA and logging.
  - Data security: encryption at rest (SSE‑KMS) and in transit (HTTPS only policies), KMS key rotation and access boundaries.
  - Change management: Terraform‑driven infra, PR approvals, pipeline audit trails (CodePipeline/CodeBuild logs retained).
  - Monitoring: CloudTrail enabled org‑wide, Config rules for S3/KMS/IAM posture, GuardDuty for anomaly detection, Macie for data classification, Security Hub centralization.
  - Backup/retention: S3 versioning + lifecycle retention; RDS snapshots and tested restores; DR replication where applicable.
  - Incident response: defined runbooks for data exfiltration, key compromise, and accidental exposure; alerts wired to on‑call.

How we’d use this here (practical stance, no code changes yet):

- Enable S3 versioning and lifecycle transitions for the app bucket(s) from Lab 08; enforce SSE‑KMS with a CMK owned by the account.
- Turn on Block Public Access at the account and bucket level; add CloudTrail data events for the bucket.
- Stand up Macie with a weekly classification job scoped to the app prefixes; integrate findings into Security Hub and create basic alerting.
- Document retention (e.g., 1 year in IA, 7 years in Deep Archive for audit‑relevant objects) and codify as lifecycle when ready.

Examples (real‑world):

- Uploads bucket (staging):
  - What: `devops-refresher-staging-uploads` with prefixes per service (`/app/avatars/*`).
  - Why: Versioning protects against accidental overwrites/deletes; lifecycle cuts storage costs.
  - When: Transition non‑current versions at 30 days to Standard‑IA, current at 90 days to Glacier Instant; expire incomplete multipart uploads after 7 days; keep delete markers 30 days.
  - How: SSE‑KMS with CMK `alias/devops-refresher-app`; IAM policy grants app task role Put/Get/Delete on `/app/*` only; presigned URLs for clients.

- Compliance bucket (prod evidence):
  - What: `devops-refresher-prod-evidence` for audit exports and logs.
  - Why: SOC 2 retention and immutability requirements.
  - When: Retain for 7 years, CRR to a secondary region/account, object lock (governance mode) if required by policy.
  - How: Enable object lock at bucket creation; use lifecycle with Glacier Deep Archive after 180 days; CloudTrail data events and Macie scanning monthly.

Data handling checklist:

- Classify data types (PII/PCI/PHI/public) and map to prefixes.
- Define retention per class (e.g., 30/365/2555 days) and required replication/immutability.
- Choose encryption model (SSE‑KMS CMK per app vs shared CMK); document key administrators and key users.
- Block public access, disable ACLs; enforce bucket owner preferred.
- Enable versioning, lifecycle transitions/expirations, abort incomplete MPU.
- Enable CloudTrail data events; wire Security Hub/Config controls and alarms.
- Scope Macie jobs (weekly/monthly) for sensitive prefixes; route findings and triage.
- Review IAM access quarterly; limit principals to least privilege and prefer presigned URLs for client uploads.

---

## Inline CLI Equivalents (manual runs)

These mirror what the labs and pipelines do, using standard CLIs. Useful for ad‑hoc verification or debugging.

- Build and push image to ECR (Docker or Buildx)

```
AWS_REGION=ap-southeast-2 \
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text) \
REPO=demo-node-app \
TAG=$(git rev-parse --short HEAD)

aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

docker build -t $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO:$TAG demo-node-app
docker push $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO:$TAG

# Get immutable digest for that tag
DIGEST=$(aws ecr describe-images \
  --repository-name $REPO \
  --image-ids imageTag=$TAG \
  --query 'imageDetails[0].imageDigest' --output text)
echo "Digest: $DIGEST"
```

- EKS: kubectl + helm (same behavior as pipeline)

```
CLUSTER=$(cd aws-labs/17-eks-cluster && terraform output -raw cluster_name)
AWS_REGION=ap-southeast-2
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER

HELM_CHART=aws-labs/kubernetes/helm/demo-app
VALUES=aws-labs/kubernetes/helm/demo-app/values.yml
REPO_URI=$(cd aws-labs/03-ecr && terraform output -raw repo_url)
CERT_ARN=$(cd aws-labs/18-eks-alb-externaldns && terraform output -raw certificate_arn)
TAG=$(git rev-parse --short HEAD)
DIGEST=$(aws ecr describe-images --repository-name demo-node-app \
  --image-ids imageTag=$TAG --query 'imageDetails[0].imageDigest' --output text)

helm upgrade --install demo-demo-app $HELM_CHART \
  -n demo --create-namespace \
  -f $VALUES \
  --set image.repository=$REPO_URI \
  --set image.tag=$TAG \
  --set image.digest=$DIGEST \
  --set ingress.certificateArn=$CERT_ARN \
  --set buildVersion=$TAG \
  --wait --atomic

kubectl -n demo rollout status deploy/demo-demo-app --timeout=180s
```

- ECS: update service to new image (AWS CLI)

```
CLUSTER_NAME=$(cd aws-labs/13-ecs-cluster && terraform output -raw cluster_name)
SERVICE_NAME=$(cd aws-labs/14-ecs-service && terraform output -raw service_name)
REPO_URI=$(cd aws-labs/03-ecr && terraform output -raw repo_url)
TAG=$(git rev-parse --short HEAD)

# Get current task definition family
TD_ARN=$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME \
  --query 'services[0].taskDefinition' --output text)
FAMILY=${TD_ARN##*/}

# Create a new task definition revision with updated image
TMP=$(mktemp)
aws ecs describe-task-definition --task-definition $TD_ARN \
  --query 'taskDefinition' > $TMP

# Update the container image (assumes first container is the app)
jq \
  --arg IMAGE "$REPO_URI:$TAG" \
  '.containerDefinitions[0].image = $IMAGE | del(.taskDefinitionArn,.revision,.status,.requiresAttributes,.compatibilities,.registeredAt,.registeredBy)' \
  $TMP > $TMP.new

NEW_TD=$(aws ecs register-task-definition --cli-input-json file://$TMP.new \
  --query 'taskDefinition.taskDefinitionArn' --output text)

aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME \
  --task-definition $NEW_TD --force-new-deployment
```

- k9s with EKS

```
CLUSTER=$(cd aws-labs/17-eks-cluster && terraform output -raw cluster_name)
aws eks update-kubeconfig --name $CLUSTER --region ap-southeast-2
k9s -n demo
```

## Goals (non-negotiable)

- One build → one image tag → deploy to ECS and EKS
- Clear repo layout: modules (pure), stacks (deployable), environments (overlays), pipelines (CI/CD)
- Centralized IAM (CI roles, ECS task roles, EKS IRSA)
- Deterministic state layout per env/stack; easy drift detection and rollback
- Runtime config in SSM/Secrets Manager; build-time config minimal
- Observability and safety rails (approvals, path guards, rollbacks)

## Golden Repository Layout

See `skeleton/` for directories to create. Top-level:

```
modules/                 # reusable terraform modules only (no remote state)
  network/
  iam/
  ecr/
  ecs-service/
  eks-app/
  observability/
stacks/                  # deployable stacks composed from modules
  shared/                # foundation shared across envs
    vpc/
    dns/
    ecr/
    iam/
  platform/              # platform controllers and clusters
    ecs/
    eks/
    observability/
  apps/
    demo-app/
      ecs/
      eks/
environments/            # env overlays and backends
  development/
  staging/
  production/
pipelines/               # CI/CD (single build → dual deploy)
  codepipeline/
  github-actions/
```

Conventions:

- Naming: kebab-case; tag resources with `Project`, `App`, `Environment`, `Owner`, `ManagedBy`.
- Modules accept inputs; no provider/backend blocks; no `data.terraform_remote_state`.
- Stacks wire modules and read remote state from prior stacks only.
- Environments own provider defaults, backend config, and tfvars.

## State & Backends

- S3 bucket: `tf-state-<account_id>-<region>` (server-side encryption, locking)
- Key scheme: `<env>/<stack>/terraform.tfstate`
  - Examples:
    - `staging/shared/vpc/terraform.tfstate`
    - `staging/platform/eks/terraform.tfstate`
    - `staging/apps/demo-app/eks/terraform.tfstate`
- Region default: `ap-southeast-2`

## IAM Strategy (centralized)

Centralize in `stacks/shared/iam` using `modules/iam`:

- CI roles:
  - CodePipeline role: Start builds, read/write artifacts, invoke deploy stages
  - CodeBuild roles:
    - build: ECR push, logs, minimal AWS read
    - deploy-ecs: ECS Describe\*/UpdateService, read ECR
    - deploy-eks: EKS DescribeCluster + kubectl via aws-auth mapping (least-privilege if using specific namespaces)
- Runtime roles:
  - ECS: task role and execution role per app
  - EKS: IRSA roles per app (annotate SA), ESO roles (if using)
- Outputs: export CI role ARNs, app runtime role ARNs for reuse in stacks/pipelines

## Networking, DNS, Images

- VPC: private subnets for workloads, public for ALBs/NAT; tags for EKS/AWS LB Controller
- Route53: hosted zones per domain; ALB aliases per app env
- ECR: 1 repo per app; image tag = commit short SHA

## Secrets & Runtime Config

- Parameter Store (non-secrets) and Secrets Manager (secrets)
- EKS: install ESO; use `ClusterSecretStore` to pull both
- ECS: reference SSM/Secrets in task definition env

## Single Build → Dual Deploy (reference design)

Stages:

1. Source: CodeConnections GitHub (branch: main)
2. Build (CodeBuild):
   - Login to ECR, docker build/push
   - Tag: `GIT_SHA=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c1-7)`
   - Emit `artifact.json` with `{ "commit_sha": "<short>" }`
3. Deploy ECS (CodeBuild or CodeDeploy):
   - Read `artifact.json`, set `IMAGE_TAG`
   - Register new task def revision with the new image tag
   - `aws ecs update-service --force-new-deployment`
4. Deploy EKS (CodeBuild):
   - `aws eks update-kubeconfig`
   - Resolve `DIGEST` for `<short>` tag from ECR
   - `helm upgrade --install` with `image.tag=<short>`, `image.digest=$DIGEST`, `image.pullPolicy=Always`, `buildVersion=<short>`, `DEPLOY_PLATFORM=eks`, `--wait --atomic`

Ordering & guards:

- EKS waits for ECR image tag to exist and pins the digest
- Optionally require ECS stage success or a manual approval between stages
- Optional path guard to run EKS only when k8s paths change

## Environment Overlays

Each env folder includes:

- `backend.hcl`: backend bucket/key prefix
- `providers.tf`: region/profile defaults
- `tags.tfvars`: Owner/Project/App/Environment tags; limits like instance types, min/max replicas
- `network.tfvars` (optional): per-env CIDRs, NAT strategy

## App Conventions

- Helm values include `env` with `DEPLOY_PLATFORM=eks` for EKS
- ECS task definition sets `DEPLOY_PLATFORM=ecs`
- Autodetection remains as fallback in the app

## Observability

- Logs: CloudWatch Logs groups per app/stage
- Metrics: CloudWatch Container Insights, ALB target metrics, EKS control plane metric ingestion
- Traces (optional): X-Ray or OTEL collector

## Safety / Rollback

- Manual approval between build and deploy stages (optional)
- Blue/green on ECS (CodeDeploy) or rolling with minHealthyPercent
- Helm `--atomic --timeout 5m` (optional) for safer rollouts
- `helm rollback` and ECS service rollback documented in runbooks

## Migration Plan (from current labs)

1. Create the skeleton folders in `skeleton/`
2. Move VPC/DNS/ECR into `stacks/shared/`
3. Move IAM into `stacks/shared/iam` and update consumers to read via remote state
4. Stand up `stacks/platform/eks` and `stacks/platform/ecs` stacks
5. Move the app under `stacks/apps/demo-app/{ecs,eks}`
6. Replace current pipelines with `pipelines/codepipeline/single-build-dual-deploy`
7. Cut over DNS to the new ALBs

## Why existing labs differ

They intentionally teach concepts in small chunks. This blueprint is the production consolidation. Keep labs as-is; adopt the blueprint when you want the cohesive structure.

---

## Why this structure? Clear boundaries and predictable locations

Plain-English mapping:

- "modules" = building blocks. Reusable, pure, no environment baked in.
- "stacks" = deployable things. Compose modules into something you apply.
- "shared" = foundational infra used by everything (VPC/DNS/ECR/IAM baseline).
- "platform" = the runtime platforms (ECS, EKS, controllers, observability).
- "apps" = your business apps (like demo-app) deployed onto a platform.

This ensures you always ask first: am I building a reusable thing (module) or deploying a stack (stack)? Then: is it foundation, platform, or an app?

### Where does everything live? (lookup table)

| Category      | Example                          | Location                                       |
| ------------- | -------------------------------- | ---------------------------------------------- |
| Networking    | VPC, subnets, NAT                | `stacks/shared/vpc/`                           |
| DNS           | Hosted zones, records            | `stacks/shared/dns/`                           |
| Images        | ECR repos                        | `stacks/shared/ecr/`                           |
| IAM (central) | CI roles, shared policies        | `stacks/shared/iam/`                           |
| ECS platform  | Cluster, capacity, defaults      | `stacks/platform/ecs/`                         |
| EKS platform  | Cluster, nodegroups, addons      | `stacks/platform/eks/`                         |
| Controllers   | ALB Controller, ExternalDNS, ESO | `stacks/platform/observability/` or subfolders |
| App on ECS    | Task def, service, LB            | `stacks/apps/<app>/ecs/`                       |
| App on EKS    | Helm chart + values              | `stacks/apps/<app>/eks/`                       |
| Reusable bits | VPC module, IAM module           | `modules/<area>/`                              |
| Env overlays  | backend, tfvars, tags            | `environments/<env>/`                          |
| Pipelines     | single build → ECS+EKS           | `pipelines/`                                   |

Navigation heuristics:

- If you can apply it to an environment, it’s under `stacks/`.
- If you intend to reuse it in multiple stacks, it’s under `modules/`.
- If it’s foundational (everyone depends on it), it’s under `stacks/shared/`.
- If it runs workloads (ECS/EKS/observability), it’s under `stacks/platform/`.
- If it’s a business app, it’s under `stacks/apps/<app>/<runtime>/`.

Naming alternatives (pick what your team prefers):

- `stacks/shared` → `stacks/foundation`
- `stacks/platform` → `stacks/runtimes` or `stacks/controls`
- `modules` → keep as-is; this is standard Terraform terminology

---

## Alternative repo layouts (choose your poison)

Different teams favor different mental models. Here are proven options with trade-offs:

### 1) Live vs Modules (HashiCorp style)

- Repos:
  - `infra-modules` (only reusable modules)
  - `infra-live` (only stacks/environments; consumes modules via versioned source)
- Pros: crisp separation; versioned module releases; easy to share modules across org
- Cons: two repos to manage; PRs may span both

### 2) Environment-first (Terragrunt-style tree)

- Layout:

```
environments/
  development/
    shared/vpc/
    platform/eks/
    apps/demo-app/eks/
  staging/
  production/
modules/
```

- Pros: everything for an env is co-located; env diffs are obvious
- Cons: duplication across env trees; longer paths; can hide module reuse

### 3) Workload-first (App-centric)

- Layout:

```
apps/
  demo-app/
    ecs/
    eks/
platform/
shared/
modules/
```

- Pros: app teams stay in one place; clearer ownership boundaries
- Cons: platform/shared dependencies feel “somewhere else”; platform teams may dislike

### 4) Mono-stack per repo (polyrepo)

- Each app gets its own repo with its own infra (modules vendored or referenced)
- Pros: autonomy per app; simple mental model for app teams
- Cons: harder shared upgrades; duplicated patterns; more pipelines

### 5) CDK-only or Pulumi-only monorepo

- Everything as code in one program; stacks are constructs/classes
- Pros: strong composition in a single language; great for dev-heavy teams
- Cons: drift from Terraform practices; ties you to a runtime/language

The blueprint here is a hybrid of (1) within a single repo for simplicity. If you strongly prefer environment-first, you can flip the tree while keeping the same modules/stacks separation.

---

## Pipelines: other ways to chain ECS and EKS

Options for ordering without the mess:

- Single pipeline with sequential stages (Build → ECS → EKS)
- Two pipelines: ECR event triggers EKS deploy only when image is pushed
- Manual approval between stages for production
- Path-based condition: run EKS stage only on k8s path changes

Artifact contract:

- The only contract between stages is the ECR image tag (commit short SHA) and an optional small `artifact.json` manifest. No other hidden coupling.

---

## IAM placement: never scatter

- All CI roles in `stacks/shared/iam/` with outputs for role ARNs
- Runtime roles:
  - ECS task roles in app ECS stacks
  - EKS IRSA roles in app EKS stacks (consumes OIDC provider outputs from `stacks/platform/eks`)
- Controllers (ALB, ExternalDNS, ESO) roles in `stacks/platform/eks` or `stacks/platform/observability`

Keep IAM documents versioned next to the stacks that require them; export role ARNs for pipelines to consume.

---

## Worked example: finding anything in 10 seconds

- “Where’s the EKS cluster?” → `stacks/platform/eks/`
- “Where’s the demo app Helm values?” → `stacks/apps/demo-app/eks/`
- “Where’s the ECS service?” → `stacks/apps/demo-app/ecs/`
- “Where’s the CI role?” → `stacks/shared/iam/`
- “Where do I add a new VPC tag?” → `stacks/shared/vpc/`
- “Where’s the ECR repo?” → `stacks/shared/ecr/`
- “Where are reusable IAM policies?” → `modules/iam/`

---

## Procedural walkthrough (descriptive only, no scaffolding)

Follow this high-signal sequence. Each step states the “what”, “where it lives”, inputs/outputs, and validation. Do this per environment (development → staging → production).

1. Decide environment primitives
   - What: Choose regions, CIDRs, tags, and naming (prefixes/suffixes).
   - Where: `environments/<env>/` docs (no code). Capture:
     - Region: `ap-southeast-2`, Profile: `devops-sandbox`
     - Tags: `Owner`, `Project`, `App`, `Environment`, `ManagedBy`
     - CIDRs and allowed ingress egress.
   - Output: One-page env sheet. Used by every stack.
   - Validate: Sanity-check CIDRs, tag keys, and naming patterns.

2. Foundation: shared VPC, DNS, ECR, IAM (central)
   - What: Create shared networking, hosted zones/records baseline, ECR repos, CI roles.
   - Where: `stacks/shared/{vpc,dns,ecr,iam}/` (described locations; keep IAM centralized).
   - Inputs: Env sheet; desired ECR repo names (e.g., `demo-node-app`).
   - Outputs: Remote state exports:
     - VPC/subnets IDs; DNS zone IDs; ECR repo URIs
     - CI role ARNs: CodePipeline, CodeBuild (build, ecs-deploy, eks-deploy)
   - Validate: VPC routability, hosted zone delegation, ECR push from a dev machine, assume-role tests for CI roles.

3. Platform runtimes: ECS and EKS
   - What: Stand up ECS (cluster/capacity) and EKS (cluster/nodegroups/add-ons) + controllers (ALB Controller, ExternalDNS; ESO later).
   - Where: `stacks/platform/{ecs,eks}/` and `stacks/platform/observability/` (for controllers).
   - Inputs: VPC IDs, OIDC provider for EKS, CI role ARNs.
   - Outputs: Cluster names/ARNs, OIDC URL/ARN, ALB controller IAM, ExternalDNS target zone IDs.
   - Validate: `aws ecs list-clusters`, `aws eks describe-cluster`, ALB controller and ExternalDNS pods healthy.

4. Application stacks layout
   - What: Define app stacks for both runtimes.
   - Where: `stacks/apps/demo-app/{ecs,eks}/` (described locations).
   - Inputs: ECR repo, cluster names, certificate ARN (from ALB/ACM), DNS hostnames.
   - Outputs: Task definition/service (ECS), Helm release (EKS).
   - Validate: `curl https://<host>` returns banner for the right platform; logs and metrics wired.

5. CI/CD: single build → dual deploy
   - What: One pipeline with stages: Source → Build → DeployECS → DeployEKS.
   - Where: `pipelines/codepipeline/single-build-dual-deploy/` (design lives here; code can reside elsewhere if you later choose).
   - Inputs: CI role ARNs (from shared IAM), connection ARN, repo name/branch, ECR repo name.
   - Contract: `commit_sha = short(CODEBUILD_RESOLVED_SOURCE_VERSION)`. Build produces image `:commit_sha` and emits a tiny `artifact.json` with `{ commit_sha }`.
   - Ordering:
     - DeployECS consumes `commit_sha` and updates service
     - DeployEKS waits for ECR image `:commit_sha` and runs `helm upgrade --install` with `image.tag=commit_sha`
     - Optional: approval before production stages; optional path guards
   - Validate: Two successful deploy stages; service healthy checks; Helm release status deployed.

6. Secrets and runtime config
   - What: Place non-secrets in SSM Parameter Store, secrets in Secrets Manager.
   - Where: Document paths like `/devops-refresher/<env>/app/*`.
   - EKS: After ESO is installed, set `externalSecrets.enabled=true` and reference `ClusterSecretStore`.
   - ECS: Task definition env from SSM/Secrets references.
   - Validate: `/readyz` passes (S3/DB/Redis if applicable), app reads expected values.

7. IAM placement (never scatter)
   - CI roles: only in `stacks/shared/iam/` with exported ARNs.
   - Runtime roles: ECS task roles in app ECS stack; IRSA roles in app EKS stack.
   - Controller roles (ALB, ExternalDNS, ESO): in EKS platform/observability stacks.
   - Validate: Assume-role tests; aws-auth mapping for the EKS deploy role.

8. DNS cutover and routing
   - What: Route53 records alias to the correct ALB per runtime.
   - EKS: Ingress ALB DNS and hosted zone ID; ECS: ALB DNS and zone.
   - Validate: `dig +short <host>` resolves; `curl` presents correct banner.

9. Observability, safety, rollback
   - Logs: CloudWatch groups per app env
   - Metrics: ALB target, ECS/EKS service metrics; Container Insights
   - Safety: approvals for prod, blue/green (ECS) or `--atomic` Helm (EKS)
   - Rollback: ECS service rollback / task def revision; `helm rollback <release> <rev>`

10. Runbooks and conventions

- Keep a short runbook for: build failures, ECS rollback, EKS rollback, DNS cutover, secret rotation.
- Capture naming/tagging and versioning rules; update when you add new stacks.

This walkthrough intentionally avoids creating files. It defines an order, locations, inputs/outputs, and validations so a team can execute predictably without hunting.

---

## Existing labs → Blueprint mapping (by resource)

This section maps what you already built in numbered labs to where those parts live in the blueprint, and lists the concrete resources that must exist. Follow the dependency order exactly.

### Foundation (shared)

1. Backend/State (00)
   - Resources: S3 state bucket, DynamoDB lock table (if used)
   - Blueprint: documented under `environments/<env>/` and platform provisioning runbooks

2. VPC (01)
   - Resources: VPC, 2–3 public subnets, 2–3 private subnets, NAT gateways, routes, tags for EKS/ALB
   - Blueprint: `stacks/shared/vpc/`
   - Outputs: vpc_id, subnet_ids (public/private), route tables

3. VPC Endpoints (02) [optional]
   - Resources: Interface/Gateway endpoints (ecr.api, ecr.dkr, s3, logs, sts, ssmmessages, etc.)
   - Blueprint: `stacks/shared/vpc/` (feature toggle)

4. ECR (03)
   - Resources: Repos: `demo-node-app`
   - Blueprint: `stacks/shared/ecr/`
   - Outputs: repo_url(s)

5. DNS (05)
   - Resources: Public hosted zone(s), ALB alias records for ECS/EKS apps
   - Blueprint: `stacks/shared/dns/`
   - Outputs: zone_id(s)

6. IAM (06)
   - Resources: CI roles (CodePipeline, CodeBuild build, CodeBuild ecs-deploy, CodeBuild eks-deploy); policies for ECR push, ECS update-service, EKS describe + cluster access; ECS task/execution roles; EKS IRSA base policies
   - Blueprint: `stacks/shared/iam/` (centralized)
   - Outputs: role_arn(s)

7. Security Groups (07)
   - Resources: SGs for ALB, ECS services, EKS nodes, controllers
   - Blueprint: `stacks/shared/vpc/` or per platform stack depending on coupling

8. S3 (08) [app data]
   - Resources: app bucket(s), policies
   - Blueprint: `stacks/shared/s3/` or app-owned in `stacks/apps/<app>/shared`

9. RDS (09) [optional for demo]
   - Resources: DB subnet group, parameter group, instance/cluster, security rules
   - Blueprint: `stacks/shared/rds/` or app-owned

10. ElastiCache Redis (10) [optional for demo]

- Resources: subnet group, parameter group, replication group
- Blueprint: `stacks/shared/redis/` or app-owned

11. Parameter Store (11)

- Resources: `/devops-refresher/<env>/app/*` parameters
- Blueprint: documented under secrets; optionally `stacks/shared/parameters/`

12. ALB (12)

- Resources: ALB(s) and listeners/target groups (ECS) or via Kubernetes Ingress (EKS)
- Blueprint: ECS ALB in `stacks/apps/<app>/ecs/`; EKS via ALB Controller in `stacks/platform/eks`

### Compute Platforms

13. ECS Cluster (13)

- Resources: ECS cluster, capacity (Fargate), CloudWatch logs, default SG
- Blueprint: `stacks/platform/ecs/`
- Outputs: ecs_cluster_name/arn

14. ECS Service (14)

- Resources: Task definition (with SSM/Secrets refs), service, target group, ALB listener rules
- Blueprint: `stacks/apps/demo-app/ecs/`
- Inputs: ECR repo URL, `commit_sha` image tag
- Outputs: service_name, task_definition_arn

17. EKS Cluster (17)

- Resources: EKS cluster, nodegroups, OIDC provider, addons (vpc-cni, coredns, kube-proxy)
- Blueprint: `stacks/platform/eks/`
- Outputs: cluster_name, oidc_provider_arn/url

18. EKS ALB + ExternalDNS (18)

- Resources: AWS LB Controller (Helm), ExternalDNS (Helm), RBAC and IAM roles
- Blueprint: `stacks/platform/eks` (controllers) or `stacks/platform/observability/`
- Outputs: certificate_arn (from ACM), confirmed DNS records

19. EKS App (19)

- Resources: Helm release for demo app, values referencing ECR, cert ARN, host, DEPLOY_PLATFORM=eks
- Blueprint: `stacks/apps/demo-app/eks/`
- Inputs: ECR repo URL, cluster name, certificate arn, host
- Outputs: Helm release name, K8s Service/Ingress

### CI/CD

15. CICD – ECS pipeline (15)

- Resources: CodePipeline (Source → Build → DeployECS), CodeBuild projects, S3 artifacts
- Blueprint target: Merged into the single pipeline as the ECS stage

20. CICD – EKS pipeline (20)

- Resources: CodePipeline (Source → Build (Helm)), waits for image tag
- Blueprint target: Merged into the single pipeline as the EKS stage

16. Observability (16)

- Resources: CloudWatch log groups, metrics configs; optional OTEL/X-Ray
- Blueprint: `stacks/platform/observability/`

## End-to-end blueprint execution (deterministic order)

1. Shared foundation: VPC → DNS → ECR → IAM → (Endpoints/SG/S3/RDS/Redis if used)
2. Platforms: EKS cluster → controllers (ALB Controller, ExternalDNS, ESO later); ECS cluster
3. App infrastructure:
   - ECS: task definition and service wired to ECR
   - EKS: Helm release using the same chart and ECR image
4. CI/CD: Single pipeline with Source → Build → DeployECS → DeployEKS
5. DNS cutover: Route app hostnames to the correct ALBs (ECS service ALB and EKS Ingress ALB)
6. Validation: curl app, check platform banner, rollout status, ECS events, K8s events

If you follow the above with the resources enumerated, you’ll reproduce the current working state with the cleaner layout and a single build feeding both deployments.

---

## Deep dives (What / Why / When / How) with examples

### VPC (stacks/shared/vpc)

- What: Provide network isolation and routing for ECS/EKS and ALBs.
- Why: Stable IP space, security boundaries, and controller autodiscovery via tags.
- When: First. Everything depends on it.
- How: Two or three AZs; public subnets for ALB/NAT; private for workloads.
- Examples (tags your labs use):
  - `kubernetes.io/cluster/<cluster-name> = shared`
  - `kubernetes.io/role/internal-elb = 1` on private; `elb = 1` on public
- Validate:
  - `aws ec2 describe-subnets --filters Name=tag:kubernetes.io/cluster/<name>,Values=shared`
  - ALB Controller discovers subnets without warnings

### IAM (stacks/shared/iam)

- What: Central CI roles and shared policies; runtime roles remain closest to workloads.
- Why: Avoid scattered privileges; clear audit and rotation; least privilege.
- When: After VPC and before pipelines; update as you add platforms/controllers.
- How: CI roles: CodePipeline, CodeBuild(build), CodeBuild(ecs-deploy), CodeBuild(eks-deploy).
- Examples (permissions):
  - Build: `ecr:GetAuthorizationToken`, `ecr:PutImage`, `logs:*`
  - ECS deploy: `ecs:Describe*`, `ecs:RegisterTaskDefinition`, `ecs:UpdateService`
  - EKS deploy: `eks:DescribeCluster` + `kubectl` via aws-auth mapping; optionally limit to a namespace with RBAC
- Validate:
  - `aws sts simulate-principal-policy` for critical actions
  - `kubectl auth can-i ...` for EKS deploy role

### ECS platform and service

- What: Cluster + service using the built image `:commit_sha`.
- Why: One of two runtimes; parity with EKS.
- When: After build pipeline exists (or use staging tag initially).
- How: Task definition env includes `DEPLOY_PLATFORM=ecs`; SSM/Secrets references for runtime config.
- Example snippet (task def env refs):
  - `valueFrom` for SSM `/devops-refresher/staging/app/APP_AUTH_SECRET`
- Validate:
  - Service event: steady state; target group healthy
  - Banner: “Running on AWS ECS Fargate with:”

### EKS platform and controllers

- What: Cluster + ALB Controller + ExternalDNS (+ ESO later).
- Why: Ingress for Helm-based apps and DNS automation.
- When: After VPC; before app Helm installs.
- How: Helm installs with IRSA; ALB Controller version compatible with cluster minor (1.31 in your labs).
- Example annotations (Ingress):
  - `alb.ingress.kubernetes.io/certificate-arn: <arn>`
  - `kubernetes.io/ingress.class: alb`
- Validate:
  - ALB created; SecurityGroups attached; `Address` present in `kubectl get ingress`
  - ExternalDNS writes record to Route53

### EKS app (Helm)

- What: Deploy demo app chart with `image.tag=<commit_sha>` and `DEPLOY_PLATFORM=eks`.
- Why: Match the ECS deployment from the same image.
- When: After controllers; after ECR tag exists.
- How: `helm upgrade --install` with values file plus `--set image.repository`, `--set image.tag`, `--set ingress.certificateArn`.
- Example values (from labs): `values.yml` with `ingress.host` and optional `externalSecrets.enabled`.
- Validate:
  - `kubectl -n demo rollout status deploy/demo`
  - Banner: “Running on Kubernetes (EKS) with:”

### Single build → dual deploy pipeline

- What: One pipeline; two deploy stages consume the same image tag.
- Why: Determinism and speed; no rebuilds per runtime.
- When: After ECR exists and CI roles are in place.
- How: Build stage produces `artifact.json` with `commit_sha` and pushes image; ECS stage updates service; EKS stage waits for image tag then runs Helm.
- Example build env:
  - `GIT_SHA=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c1-7)`
  - `docker build -t $REPO_URI:$GIT_SHA . && docker push $REPO_URI:$GIT_SHA`
- Validate:
  - Both deploy stages green; each points at the same tag

### DNS and certificates

- What: Route app hostnames to the correct ALBs; ACM certs in the region.
- Why: TLS and discoverability.
- When: Post-deploy; cutover when healthy.
- How: Route53 alias to ALB DNS with canonical zone ID; ACM cert validated for domains.
- Validate:
  - `dig +short <host>` yields ALB IPs; TLS succeeds; curl shows correct banner

### Secrets and config

- What: Store runtime config in SSM/Secrets; project into ECS/EKS differently.
- Why: No bake-time secrets; identical image runs everywhere.
- When: Before app deploy; rotate without rebuilds.
- How: ECS: task definition envFrom valueFrom; EKS: ESO ExternalSecret once ESO installed.
- Validate:
  - `/readyz` passes; app can reach S3/DB/Redis; auth token protects endpoints
