# Build-Time vs Runtime Configuration

This guide explains where to put build-time variables (Docker build args) and runtime environment variables for apps in this repo, plus how to decide which to use and how to recognize when you need them.

## TL;DR

- Build-time variables: Docker `ARG` passed during `docker build`. Used to influence the image contents (compile assets, select build target, embed version). Not available at runtime. Do not use for secrets.
- Runtime variables: Container `environment` and `secrets` in the orchestrator (ECS/EKS). Used by the app process at startup and during execution. Use `secrets` for sensitive values from SSM/Secrets Manager.

## Where They Go In This Repo

- Build-time
  - Local/CI builds that publish to ECR: set with `docker build --build-arg KEY=VAL`.
  - Reference: `aws-labs/03-ecr/README.md` for pushing images; extend those commands with `--build-arg` as needed.
  - Dockerfile usage: declare `ARG KEY` and optionally promote to an `ENV` default if the app must read it at runtime.

- Runtime (ECS)
  - File: `aws-labs/05-ecs/main.tf:176` — non-sensitive container env vars defined under `container_definitions.environment`.
  - Secrets: prefer `container_definitions.secrets` for sensitive values; source from SSM Parameter Store or Secrets Manager. The task role already has SSM read access for `/devops-refresher/staging/*` at `aws-labs/05-ecs/main.tf:116`.
  - Variables: tweak defaults like app port and healthcheck in `aws-labs/05-ecs/variables.tf`.

Example secrets block for ECS (add alongside `environment` in `aws-labs/05-ecs/main.tf`):

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

## Pointers In This Repo

- `aws-labs/03-ecr/README.md` — how to build/tag/push images to ECR.
- `aws-labs/05-ecs/main.tf:176` — example runtime env for the ECS task.
- `docs/demo-apps.md` — demo app expectations (port, health, env keys).

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
