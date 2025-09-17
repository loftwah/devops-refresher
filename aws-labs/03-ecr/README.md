# Lab 03 — ECR (Private Repo, Base Images, Optional Cache)

## Overview

This lab provisions a private Amazon ECR repository for your application images with on‑push scanning and a lifecycle policy. It also covers a base‑image strategy: prefer AWS ECR Public when images exist there; otherwise, optionally enable an ECR Pull‑Through Cache (PTC) to mirror other public registries (e.g., Docker Hub, ghcr.io) into your account.

## Base Images: ECR Public vs Pull‑Through Cache

- ECR Public: Use this when an official image exists on AWS’s public registry, for example `public.ecr.aws/docker/library/node:20-alpine`.
  - Pros: fewer rate limits than Docker Hub; AWS‑hosted; simple path; widely mirrored.
  - Cons: requires internet/NAT egress from private subnets (no VPC endpoints for ECR Public).
  - Dockerfile example: `FROM public.ecr.aws/docker/library/node:20-alpine`.

- Pull‑Through Cache (PTC): Use this when you rely on non‑AWS public registries (Docker Hub, ghcr.io, quay.io) and want to centralize pulls or avoid rate limits.
  - Pros: pulls via your private ECR domain; compatible with ECR VPC Interface Endpoints for private egress; central auditing/controls.
  - Cons: first pull fetches from upstream (slightly slower); cache repos created lazily; manage a prefix convention.
  - Dockerfile example: `FROM <account>.dkr.ecr.<region>.amazonaws.com/dockerhub/library/node:20-alpine`.

Do you need a pull‑through cache when using AWS ECR Public? No — ECR Public is already a public registry hosted by AWS; reference it directly. Use PTC specifically for non‑AWS public registries you want to pull through ECR.

## What This Folder Contains

- `versions.tf` — Terraform core/provider constraints
- `backend.tf` — S3 backend (`staging/ecr/terraform.tfstate`)
- `providers.tf` — AWS provider with default tags
- `variables.tf` — Inputs (region, repo name, lifecycle, PTC toggles)
- `main.tf` — ECR repository, lifecycle policy, optional PTC rule
- `outputs.tf` — `repository_url`, `repository_name`, `repository_arn`, cache hint

Defaults reflect the app name:

- Repository name: `demo-node-app` (override with `-var repo_name=...` if needed)

## Inputs

- `region` (string): AWS region (default `ap-southeast-2`)
- `repo_name` (string): ECR repo name (default `demo-node-app`)
- `image_tag_mutability` (string): `MUTABLE|IMMUTABLE` (default `MUTABLE`)
- `lifecycle_keep_last` (number): keep last N images (default `10`)
- `force_delete` (bool): allow repo deletion with images (default `true` for labs)
- `enable_kms_encryption` (bool) + `kms_key_arn` (string): optional CMK
- `enable_pull_through_cache` (bool): enable PTC (default `false`)
- `upstream_registry_url` (string): upstream public registry (default Docker Hub)
- `ecr_cache_prefix` (string): cache prefix (default `dockerhub`)
- `tags` (map): base tags

## Create The Repo

```bash
cd aws-labs/03-ecr
terraform init
terraform apply \
  -var region=ap-southeast-2 \
  -var repo_name=demo-node-app \
  -auto-approve
```

Outputs:

- `repository_url` — use this for docker tag/push (and in CI)

## Push Your App Image

```bash
AWS_REGION=ap-southeast-2
AWS_PROFILE=devops-sandbox

aws ecr get-login-password --region $AWS_REGION --profile $AWS_PROFILE \
 | docker login --username AWS --password-stdin \
   $(aws sts get-caller-identity --profile $AWS_PROFILE --query 'Account' --output text).dkr.ecr.$AWS_REGION.amazonaws.com

REPO=$(aws ecr describe-repositories --repository-names demo-node-app --profile $AWS_PROFILE --region $AWS_REGION --query 'repositories[0].repositoryUri' --output text)

docker build -t demo-node-app:staging .
docker tag demo-node-app:staging "$REPO:staging"
docker push "$REPO:staging"

# Optional immutable tag (git SHA)
GIT_SHA=$(git rev-parse --short HEAD)
docker tag demo-node-app:staging "$REPO:$GIT_SHA"
docker push "$REPO:$GIT_SHA"
```

Validate:

```bash
aws ecr describe-images \
  --repository-name demo-node-app \
  --query 'imageDetails[].imageTags' --output table \
  --region $AWS_REGION --profile $AWS_PROFILE
```

## Enable And Use Pull‑Through Cache (Optional)

What it is: a PTC lets you reference public images via your own ECR domain. On first pull, ECR fetches from the upstream public registry and caches it under your configured prefix; subsequent pulls hit your cache.

Path format: `<account-id>.dkr.ecr.<region>.amazonaws.com/<prefix>/<upstream-path>:<tag>`

Apply with cache enabled:

```bash
terraform apply -auto-approve \
  -var enable_pull_through_cache=true \
  -var upstream_registry_url=registry-1.docker.io \
  -var ecr_cache_prefix=dockerhub
```

Pull a public base image via ECR cache:

```bash
ACCOUNT=$(aws sts get-caller-identity --profile $AWS_PROFILE --query 'Account' --output text)
docker pull $ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/dockerhub/library/node:20-alpine
```

Use in Dockerfile (example base image path):

```dockerfile
FROM <account>.dkr.ecr.<region>.amazonaws.com/dockerhub/library/node:20-alpine
```

## Networking Notes (VPC Endpoints)

For private subnets without NAT, add VPC Interface Endpoints for private ECR (including PTC):

- `com.amazonaws.<region>.ecr.api`
- `com.amazonaws.<region>.ecr.dkr`

Note: ECR Public does not use these interface endpoints; it requires internet/NAT egress. Also consider CloudWatch Logs and S3 endpoints for private builds. This repo already provides a VPC endpoints lab.

## CI/CD Handoff

Use `outputs.repository_url` in build pipelines (e.g., CodeBuild) to tag and push.

- IAM roles and permissions for CI/CD live in `aws-labs/06-iam` (includes ECR push/pull, logs, and PassRole for ECS deploys).
- The end-to-end ECS CI/CD example is `aws-labs/15-cicd-ecs-pipeline`, which builds the image, pushes to ECR, and deploys to the ECS service.

## Lifecycle & Scanning

- On‑push scanning is enabled by default.
- Lifecycle policy keeps the last `lifecycle_keep_last` images and effectively preserves the `staging` tag.

## Why It Matters

- Unused images accumulate costs; lifecycle policies keep storage tidy. Scan‑on‑push surfaces high‑severity CVEs early. Some advanced scanning features vary by region; ap-southeast-2 supports scan-on-push.

## Cleanup

This lab sets `force_delete = true` for convenience. To destroy:

```bash
terraform destroy -auto-approve
```

If deletion is blocked, ensure `force_delete=true` or delete all images first.

## Troubleshooting

- `docker login` fails: ensure the `aws ecr get-login-password` command uses the same region/profile as the repo.
- Private subnets can’t pull: ensure NAT or ECR interface endpoints are present and DNS support/hostnames are enabled in the VPC.
- PTC not working: confirm the image path includes your prefix and upstream path (e.g., `dockerhub/library/...`).

## Check Your Understanding

- When would you use ECR Public vs a Pull‑Through Cache?
- Which role needs permissions to push to ECR, and which to pull at runtime?

---

For the high‑level lab narrative, also see `aws-labs/03-ecr.md`.

## Multi‑Architecture Builds (ARM64 and x86_64)

Why: ECS Fargate supports both `ARM64` and `X86_64`. You can either publish a single‑arch image that matches your task’s CPU architecture or publish a multi‑arch manifest so a single tag works across both.

Option A — Single‑arch build (match your Fargate tasks)

```bash
# Build for ARM64 only (Apple Silicon, Graviton)
docker buildx build --platform linux/arm64 -t "$REPO:staging" --push .

# Or build for x86_64 only (Intel/AMD)
docker buildx build --platform linux/amd64 -t "$REPO:staging" --push .
```

Option B — Multi‑arch manifest (one tag for both)

```bash
# Build and push both variants under a single tag using Buildx
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t "$REPO:staging" \
  --push .
```

Notes

- Ensure base images support both architectures (e.g., `public.ecr.aws/docker/library/node:20-alpine`).
- Cross‑building on x86 for ARM (or vice versa) uses emulation; native builders are faster. In CI, add QEMU (see `docs/build-secrets-examples.md`).
- With a multi‑arch tag, ECS pulls the correct image based on your task definition `cpuArchitecture`.

Validate

```bash
# Inspect manifest list locally
docker buildx imagetools inspect "$REPO:staging"

# Confirm ECS tasks pull successfully when runtime_platform cpuArchitecture matches
```
