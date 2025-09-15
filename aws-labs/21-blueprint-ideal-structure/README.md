# Lab 21 – Blueprint: Production-Grade Structure and Pipelines (Theory)

This lab is the clean, production-grade design we planned: a single build producing one immutable image that deploys to ECS and EKS, with clear separation of modules vs stacks, environment overlays, and centralized IAM. It does not modify existing labs; those remain as incremental concept labs. Use this when you want a cohesive, shippable structure.

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
   - `helm upgrade --install` with `image.tag=<short>`, `DEPLOY_PLATFORM=eks`

Ordering & guards:

- EKS waits for ECR image tag to exist
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
- Example values (from labs): `values-eks-staging-app.yaml` with `ingress.host` and optional `externalSecrets.enabled`.
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
