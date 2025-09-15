# Build-Time vs Runtime Configuration

This guide explains where to put build-time variables (Docker build args) and runtime environment variables for apps in this repo, plus how to decide which to use and how to recognize when you need them.

## TL;DR

- Build-time variables: Docker `ARG` passed during `docker build`. Used to influence the image contents (compile assets, select build target, embed version). Not available at runtime. Do not use for secrets.
- Runtime variables: Container `environment` and `secrets` in the orchestrator (ECS/EKS). Used by the app process at startup and during execution. Use `secrets` for sensitive values from SSM/Secrets Manager.
- Platform flag: The app auto-detects the orchestrator (ECS/EKS) at runtime. You can hard-override with `DEPLOY_PLATFORM` (also accepts `RUN_PLATFORM` or `PLATFORM`).

## Where They Go In This Repo

- Build-time
  - Local/CI builds that publish to ECR: set with `docker build --build-arg KEY=VAL`.
  - Reference: `aws-labs/03-ecr/README.md` for pushing images; extend those commands with `--build-arg` as needed.
  - Dockerfile usage: declare `ARG KEY` and optionally promote to an `ENV` default if the app must read it at runtime.

- Runtime (ECS)
  - File: `aws-labs/05-ecs/main.tf:176` — non-sensitive container env vars defined under `container_definitions.environment`.
  - Secrets: prefer `container_definitions.secrets` for sensitive values; source from SSM Parameter Store or Secrets Manager. The task role already has SSM read access for `/devops-refresher/staging/*` at `aws-labs/05-ecs/main.tf:116`.
  - Variables: tweak defaults like app port and healthcheck in `aws-labs/05-ecs/variables.tf`.

Default platform flag on ECS

- The ECS task definition now injects `DEPLOY_PLATFORM=ecs` by default in `aws-labs/14-ecs-service/main.tf`.
- You can still override via `-var 'environment=[{name="DEPLOY_PLATFORM",value="ecs"}]'`.

Example secrets block for ECS (add alongside `environment` in `aws-labs/14-ecs-service/main.tf`):

```hcl
secrets = [
  { name = "DB_PASSWORD", valueFrom = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/devops-refresher/staging/app/DB_PASSWORD" }
]
```

## When To Use Which

- Use build-time variables when:
  - You need to alter the image filesystem or build behavior: choose a build target, install optional deps, compile assets differently, or embed metadata like `COMMIT_SHA`.
  - The value is not a secret and does not need to change without rebuilding.

- Use runtime variables when:
  - Configuration may vary per environment (staging/prod) without rebuilding: ports, feature flags, external endpoints, region, bucket names.
  - The value is sensitive (credentials, tokens) — inject via `secrets` from SSM/Secrets Manager.

## How To Know What You Need

- Check the Dockerfile:
  - `ARG FOO` indicates a build-time variable. If a build step fails with "FOO not set" or you see `--build-arg FOO=...` in docs/CI, it’s build-time.
  - `ENV FOO=...` sets a runtime default inside the image; can still be overridden at runtime by the orchestrator.

- Check application code:
  - Node.js: looks like `process.env.FOO`. That means runtime. If the app logs missing `FOO` or crashes on startup, it expects a runtime var.
  - Other languages have similar patterns (e.g., Go: `os.Getenv("FOO")`).

- Check runtime manifests:
  - ECS task definitions contain `environment`/`secrets` for runtime config. This repo sets examples in `aws-labs/05-ecs/main.tf:176`.

## Usage Examples

- Build-time (embed version):
  - Dockerfile:
    ```dockerfile
    ARG COMMIT_SHA
    LABEL org.opencontainers.image.revision=$COMMIT_SHA
    ```
  - Build: `docker build --build-arg COMMIT_SHA=$(git rev-parse --short HEAD) -t demo-node-app:staging .`

- Runtime (non-secret and secret) on ECS:
  - Non-secret: `APP_ENV`, `S3_BUCKET` are set in the task definition at `aws-labs/05-ecs/main.tf:176`.
  - Secret: add a `secrets` entry referencing SSM as shown above; ensure the parameter exists and the task role can read it (policy at `aws-labs/05-ecs/main.tf:116`).

## Principles & Gotchas

- Do not put secrets in Docker `ARG` or `ENV` — layers are cached and inspectable.
- Prefer 12‑factor style config: keep images immutable and vary behavior with runtime env.
- If you need a value at both build and runtime (e.g., `NODE_ENV=production`), pass it twice: `--build-arg NODE_ENV=production` and set it in the task definition `environment`.
- For private subnets without NAT, ensure VPC endpoints for ECR and CloudWatch Logs so tasks can pull images and write logs.
- Architecture: If targeting both ARM64 and X86_64 (e.g., Fargate on Graviton and Intel), build multi‑arch images with Buildx or ensure your tag matches the task definition’s `cpuArchitecture`.

## Finding What You Actually Need (Build vs Runtime)

Use these checks to figure out which values are required and whether they’re build-time or runtime:

- Dockerfile signals build-time vs runtime
  - `ARG FOO` → build-time input. Search for it and where it’s used.
  - `ENV FOO=...` → default runtime value inside the image. Can be overridden by orchestrator.
  - Quick grep locally: `rg -n "^\s*ARG\s+|^\s*ENV\s+" Dockerfile*` (run at the repo root).

- CI/CD and build scripts
  - Look for `--build-arg` usage in scripts and pipelines: `rg -n "--build-arg" .`.
  - Check GitHub Actions/CodeBuild steps that pass parameters into the build.

- Application code (runtime hints)
  - Node.js: `process.env.MY_VAR`
  - Python: `os.environ["MY_VAR"]` or `os.getenv("MY_VAR")`
  - Go: `os.Getenv("MY_VAR")`
  - Ruby: `ENV["MY_VAR"]`
  - Scan: `rg -n "process\.env\[?|os\.environ|os\.Getenv|ENV\[" src/ app/` (adjust folders per app).

- Runtime manifests
  - ECS task definitions (Terraform in this repo): `aws-labs/05-ecs/main.tf` under `container_definitions.environment` and `container_definitions.secrets`.
  - Kubernetes manifests/Helm: look for `env`, `envFrom`, `secretKeyRef`, and CSI Secret Store usage.

- Error logs and startup messages
  - Missing config usually surfaces as startup errors. If the app crashes on boot for `MY_VAR` missing, it’s a runtime requirement.

Tip: Maintain a short README per service listing required runtime env keys and whether each is a secret. Keep non-secrets in SSM Parameter Store (String) and secrets in Secrets Manager.

## Build-Time Secrets with BuildKit (Modern Way)

Do not use `ARG` for secrets. Instead, use BuildKit secret mounts so secrets are available only during the specific `RUN` step and are not persisted in layers or the final image.

- Enable BuildKit and modern syntax
  - Add the directive at the top of your Dockerfile: `# syntax=docker/dockerfile:1.7`
  - Build with Buildx: `docker buildx build ...` (or `DOCKER_BUILDKIT=1 docker build ...`).

- Passing a secret from a file (local dev/CI)
  - CLI: `docker buildx build --secret id=npmrc,src=$HOME/.npmrc -t myimg .`
  - Dockerfile:
    ```dockerfile
    # syntax=docker/dockerfile:1.7
    FROM node:20-alpine AS deps
    WORKDIR /app
    COPY package*.json ./
    # Mount .npmrc only for this step; it won’t persist in layers
    RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm ci
    ```

- Passing a secret from an environment variable (CI friendly)
  - CLI: `docker buildx build --secret id=npm_token,env=NPM_TOKEN -t myimg .`
  - Dockerfile:
    ```dockerfile
    RUN --mount=type=secret,id=npm_token sh -lc 'npm config set //registry.npmjs.org/:_authToken=$(cat /run/secrets/npm_token) && npm ci'
    ```

- Private Git dependencies via SSH (no secret files baked)
  - CLI: `docker buildx build --ssh default -t myimg .`
  - Dockerfile:
    ```dockerfile
    # syntax=docker/dockerfile:1.7
    FROM alpine/git AS src
    # Forward your SSH agent; key stays outside the image
    RUN --mount=type=ssh git clone git@github.com:org/private-repo.git /tmp/repo
    ```

- Ruby/Bundler private gems example
  - CLI: `docker buildx build --secret id=bundle_config,src=$HOME/.bundle/config -t myimg .`
  - Dockerfile:
    ```dockerfile
    # syntax=docker/dockerfile:1.7
    FROM ruby:3.2-slim AS builder
    WORKDIR /app
    COPY Gemfile Gemfile.lock ./
    RUN --mount=type=secret,id=bundle_config,target=/root/.bundle/config bundle install --jobs 4 --retry 3
    ```

- Why this is safe(r)
  - Secret material is only available during the specific `RUN` step and via `/run/secrets/<id>` (or a chosen target path).
  - Build cache does not store the secret content; `docker history` won’t reveal it.

### Migrating from ARG-based secrets

Before (insecure):

```dockerfile
ARG NPM_TOKEN
RUN npm config set //registry.npmjs.org/:_authToken=$NPM_TOKEN && npm ci
```

After (BuildKit secret):

```dockerfile
# syntax=docker/dockerfile:1.7
RUN --mount=type=secret,id=npm_token sh -lc 'npm config set //registry.npmjs.org/:_authToken=$(cat /run/secrets/npm_token) && npm ci'
```

Build command:

```
docker buildx build --secret id=npm_token,env=NPM_TOKEN -t myimg .
```

Result: No `ARG` for secrets. Nothing persists in layers.

## Runtime Secrets and Config (Recap)

- ECS: put sensitive values under `container_definitions.secrets` using SSM/Secrets Manager ARNs. Non-secrets go under `environment`.
- EKS: prefer the Secrets Store CSI driver and sync to Kubernetes Secrets only when necessary; then use `envFrom`/`secretKeyRef`.
- Parameter Store (SSM): keep non-secrets (`String`) centralized and versioned; fetch at runtime or sync into orchestrator secrets if needed.

## Quick Checklist

- Build-time
  - Are all `ARG`s documented with defaults or CI inputs?
  - Are any secrets mistakenly passed via `ARG`? Migrate to BuildKit `--secret`.

- Runtime
  - Do manifests define required `environment` and `secrets`? Are IAM permissions in place?
  - Does the app validate required env on startup and log helpful errors?

## Pointers In This Repo

- `aws-labs/03-ecr/README.md` — how to build/tag/push images to ECR.
- Multi‑arch builds and manifests: see `aws-labs/03-ecr/README.md` (multi‑arch section) and `docs/build-secrets-examples.md` (Buildx QEMU/Platforms).
- `aws-labs/05-ecs/main.tf:176` — example runtime env for the ECS task.
- `docs/demo-apps.md` — demo app expectations (port, health, env keys).
- `docs/build-secrets-examples.md` — practical BuildKit secret examples for npm, Yarn, Vite, Rails/Webpacker, and Bundler.

## CI/CD Mapping (CodeBuild/CodePipeline, GitHub Actions)

Below are concrete pipeline examples showing where build-time vs runtime configuration lives, using the ECR repo:

`139294524816.dkr.ecr.ap-southeast-2.amazonaws.com/demo-node-app`

### AWS CodeBuild (buildspec.yml)

Build-time values are passed as `--build-arg`; runtime values are not baked into the image — they’re provided by ECS when deployed.

```yaml
version: 0.2
env:
  variables:
    IMAGE_REPO: 139294524816.dkr.ecr.ap-southeast-2.amazonaws.com/demo-node-app
    NODE_ENV: production # build-time (non-secret)
  parameter-store:
    # Example: token for private dependency fetch during build (ephemeral)
    # Avoid promoting this into the runtime image; do not use as a build-arg unless absolutely necessary.
    NPM_TOKEN: /devops-refresher/staging/app/NPM_TOKEN
phases:
  pre_build:
    commands:
      - aws --version
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - COMMIT_SHA=$(echo ${CODEBUILD_RESOLVED_SOURCE_VERSION:-HEAD} | cut -c1-7)
  build:
    commands:
      # Use NPM token for dependency install via .npmrc or buildkit secret mounts; do not bake it into the image.
      - docker build \
        --build-arg COMMIT_SHA=$COMMIT_SHA \
        --build-arg NODE_ENV=$NODE_ENV \
        -t $IMAGE_REPO:staging .
  post_build:
    commands:
      - docker push $IMAGE_REPO:staging
      - printf '{"image":"%s"}' "$IMAGE_REPO:staging" > imageDetail.json
artifacts:
  files:
    - imageDetail.json
```

In CodePipeline, pass `imageDetail.json` to an ECS deploy action. Runtime env/secrets remain defined in the ECS task definition; you typically deploy by tag (`staging`) or digest for immutability.

### GitHub Actions (build and push to ECR)

```yaml
name: build-push
on:
  push:
    branches: [main]
permissions:
  id-token: write
  contents: read
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-region: ap-southeast-2
          # Choose one:
          # role-to-assume: arn:aws:iam::139294524816:role/gha-ecr-pusher
          # OR access-key-id/secret-access-key (less preferred)
      - uses: aws-actions/amazon-ecr-login@v2
      - name: Build and push
        env:
          REPO: 139294524816.dkr.ecr.ap-southeast-2.amazonaws.com/demo-node-app
        run: |
          COMMIT_SHA=$(git rev-parse --short HEAD)
          docker build \
            --build-arg COMMIT_SHA=$COMMIT_SHA \
            --build-arg NODE_ENV=production \
            -t $REPO:staging .
          docker push $REPO:staging
```

Alternative using `docker/build-push-action`:

```yaml
- name: Build and push (Buildx)
  uses: docker/build-push-action@v6
  with:
    context: .
    push: true
    tags: |
      139294524816.dkr.ecr.ap-southeast-2.amazonaws.com/demo-node-app:staging
    build-args: |
      COMMIT_SHA=${{ github.sha }}
      NODE_ENV=production
```

Deployment then updates the ECS service to use the `staging` tag (or a SHA tag). Runtime env/secrets are unchanged and come from the ECS task definition.

## Choosing Tags and Promotion

- Use a mutable environment tag (e.g., `staging`) for continuous updates in that environment, plus an immutable tag (short SHA) for traceability.
- In Terraform (`aws-labs/05-ecs/variables.tf`), `image_tag` defaults to `staging`. You can switch to a SHA tag for pinning a specific build.
- Prefer deploying by digest in automated pipelines for immutability while keeping a friendly tag for humans.
