## Lab 15 – CI/CD: GitHub → CodePipeline → ECS

This lab wires your demo Node app repo (`loftwah/demo-node-app`) to AWS using CodePipeline + CodeBuild and deploys to the ECS service from Lab 14. It uses your existing GitHub CodeConnections (formerly CodeStar Connections) setup.

Key defaults in this lab:

- GitHub repo: `loftwah/demo-node-app`
- Connection ARN: `arn:aws:codeconnections:ap-southeast-2:139294524816:connection/9cb5e242-3d9c-4b3c-8fec-fd3fdea9e37e`
- ECS Cluster: `devops-refresher-staging`
- ECS Service: `app`
- ECR Repo: `demo-node-app`

Prereqs

- Complete the console handshake for GitHub under AWS CodeConnections and grant access to only the repo you want (user account is fine). See screenshots in `images/`:
  - `images/github-aws-connector.png` (GitHub App permissions)
  - `images/codepipeline-github-connection.png` and `images/codepipeline-github-connection-2.png` (connection selection in CodePipeline)
- Ensure the ECS cluster and service from Labs 13/14 exist, and you have an ECR repo named `demo-node-app` (Lab 03).
- The app repo should contain a `buildspec.yml` that builds the Docker image, logs in to ECR, pushes, and writes `imagedefinitions.json` for ECS deploy. See `aws-labs/04-demo-app.md` for an example.

Usage

1. Change directory and review variables

```
cd aws-labs/15-cicd-ecs-pipeline
```

Variables (see `variables.tf`) let you override:

- `connection_arn` (defaults to your ARN)
- `repo_full_name` (defaults to `loftwah/demo-node-app`)
- `branch` (defaults to `main`)
- `cluster_name` / `service_name` (ECS deploy target)
- `ecr_repo_name` (ECR repository name)
- `artifacts_bucket_name` (S3 bucket for pipeline artifacts)

2. Apply in the region where your connection exists

The CodeConnections connection and the CodePipeline must be in the same region. Export your profile/region accordingly, for example:

```
export AWS_PROFILE=devops-sandbox
export AWS_REGION=ap-southeast-2
terraform init
terraform apply -auto-approve
```

3. Trigger and observe

- Push a commit to the selected branch (`main` by default) on `loftwah/demo-node-app`.
- The pipeline should:
  - Source from GitHub via your Connection ARN
  - Run CodeBuild, which builds/pushes the Docker image to ECR and writes `imagedefinitions.json`
  - Wait for a Manual Approval gate
  - Deploy to ECS using the `ECS` deploy action (cluster=`devops-refresher-staging`, service=`app` by default)
- Verify the ECS service rolls new tasks while the ALB target health stays healthy.

Helper scripts (optional)

- Kick off a run:
- `aws-labs/scripts/codepipeline-start.sh` (defaults to `devops-refresher-app-pipeline` and `ap-southeast-2`)
- Wait for success and summarize:
  - `aws-labs/scripts/verify-pipeline.sh`
- Confirm ECS service is stable and print the current image:
  - `aws-labs/scripts/verify-ecs.sh`
- Probe app health if you know the ALB URL:
  - `aws-labs/scripts/verify-app-health.sh https://<alb-dns-or-domain>`

Notes

- CodeConnections naming: AWS consoles still say "CodeStar Connections" in some places, but the API/ARNs are under `codeconnections`.
- GitHub user accounts: the connection works the same as orgs, but you must explicitly authorize the single repo in the GitHub App settings (which you’ve done).
- If you prefer GitHub Actions + OIDC, see `docs/demo-apps.md` for an Actions example; this lab focuses on CodePipeline.

### Platform detection in the app

- The app auto-detects ECS/EKS and updates the homepage banner.
- Explicit override via `DEPLOY_PLATFORM` (also accepts `RUN_PLATFORM` or `PLATFORM`) takes precedence.
- This lab’s ECS task injects `DEPLOY_PLATFORM=ecs` by default; you can override via `-var 'environment=[{name="DEPLOY_PLATFORM",value="ecs"}]'`.

Inline Buildspec (Terraform‑managed)

- This lab injects the buildspec inline into the CodeBuild project. Toggle via variables in `aws-labs/15-cicd-ecs-pipeline/variables.tf`:
  - `use_inline_buildspec = true` (default)
  - `inline_buildspec_override` to replace the default YAML if needed
- To use a buildspec in the app repo instead, set `use_inline_buildspec = false` and commit a `buildspec.yml` at the repo root.
- Rationale, tradeoffs, and decision record: `docs/decisions/ADR-004-buildspec-location.md`.

Artifacts Bucket (speed and uniqueness)

- S3 bucket creation can be slow if a name was recently deleted or already exists. To avoid delays:
  - `create_artifacts_bucket`: set `true` to create, `false` to reuse an existing bucket by name.
  - `artifacts_bucket_randomize`: when creating, appends a short random suffix to ensure global uniqueness (default `true`).
- `artifacts_bucket_name`: base name used (and used as-is when reusing).
- The pipeline always points to the effective name; IAM policies are generated for that ARN.
- Decision record: see `docs/decisions/ADR-006-artifacts-bucket-policy-ownership.md` for why the bucket policy lives in this lab (resource-owned policy) and grants access to both CodePipeline and CodeBuild roles.

Ownership & Order (IAM vs CI/CD)

- IAM ownership: Lab 06 owns CI/CD roles; this lab reads them from Lab 06 remote state.
- Apply order: Apply `aws-labs/06-iam` first, then this lab.
- If roles already exist (created earlier by this lab), import them into Lab 06 (see “Migration Note” in `aws-labs/06-iam/README.md`).

Common Failures and Fixes

- Source permission error: “Unable to use Connection … The provided role does not have sufficient permissions.”
  - Cause: Missing `codestar-connections:UseConnection` on CodePipeline role for your connection ARN.
  - Fix: Lab 06 CodePipeline role policy includes this permission. Apply Lab 06; re-apply this lab.
- Bucket validation race: “No bucket with the name … was found. Choose a valid artifact bucket in ap-southeast-2.”
  - Cause: CodePipeline validated before S3 bucket fully propagated.
  - Fix: This lab enforces ordering via `depends_on` and supports randomized bucket names to avoid recreate delays. Re-apply once.
- Unsupported attribute for IAM outputs in this lab
  - Cause: Lab 06 outputs not present yet (not applied).
  - Fix: Apply `aws-labs/06-iam` first (or import existing roles), then re-apply this lab.
- Region mismatch
  - Cause: CodeConnections ARN is in `ap-southeast-2`; pipeline in wrong region.
  - Fix: Provider for this lab uses `var.region` (default `ap-southeast-2`). Keep pipeline and connection in same region.

Troubleshooting (Copy/Paste)

- Check artifacts bucket policy grants BOTH roles (CodePipeline + CodeBuild):

  ```bash
  aws s3api get-bucket-policy --bucket <your-artifacts-bucket> --query Policy | jq -r .
  # Expect principals for both roles and actions: s3:GetObject, s3:GetObjectVersion, s3:PutObject, s3:GetBucketVersioning
  ```

- Inspect CodePipeline role policy for ECS actions:

  ```bash
  aws iam get-role-policy \
    --role-name devops-refresher-codepipeline-role \
    --policy-name devops-refresher-codepipeline \
    --query 'PolicyDocument.Statement[].Action'
  # Expect: ecs:DescribeClusters, ecs:DescribeServices, ecs:DescribeTaskDefinition, ecs:RegisterTaskDefinition, ecs:UpdateService
  ```

- One-shot validation (recommended):

  ```bash
  ../scripts/validate-cicd.sh
  ```

  - The validator simulates IAM permissions for ECS actions and `iam:PassRole` against the actual task roles, using both principals (`ecs-tasks.amazonaws.com` and `ecs.amazonaws.com`). If it passes, your deploy stage will have the permissions it needs.

CI vs CD Flow (and what to echo)

- CI (CodeBuild): Validates, builds, packages, tags images, emits `imagedefinitions.json` with immutable SHA.
  - Typical steps to echo for clarity:
    - install: "[CI] install deps" (e.g., `npm ci`)
    - pre_build: "[CI] lint/test" (optional), "[CI] compile", "[CI] resolve account/region/repo", "[CI] ecr login", "[CI] tags => staging and <git-sha>"
    - build: "[CI] docker build => <repo>:staging and <repo>:<git-sha>"
    - post_build: "[CI] push images", "[CI] write imagedefinitions.json => <repo>:<git-sha>"
  - Mock buildspec core (echo focused):
    ```yaml
    version: 0.2
    phases:
      install:
        commands:
          - echo "[CI] install deps"; npm ci --no-audit --no-fund
      pre_build:
        commands:
          - echo "[CI] lint/test"; npm run lint || true; npm test || true
          - echo "[CI] compile"; npm run build
          - echo "[CI] resolve account/region/repo"
          - ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
          - REGION=${AWS_REGION:-${AWS_DEFAULT_REGION:-ap-southeast-2}}
          - REPO_URI=${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${IMAGE_REPO_NAME}
          - echo "[CI] ecr login for ${REPO_URI}"; aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com
          - GIT_SHA=$(echo ${CODEBUILD_RESOLVED_SOURCE_VERSION} | cut -c1-7)
          - echo "[CI] tags => staging and ${GIT_SHA}"
      build:
        commands:
          - echo "[CI] docker build => ${REPO_URI}:staging and ${REPO_URI}:${GIT_SHA}"
          - docker build --platform=linux/amd64 -t ${REPO_URI}:staging -t ${REPO_URI}:${GIT_SHA} .
      post_build:
        commands:
          - echo "[CI] push images"; docker push ${REPO_URI}:staging; docker push ${REPO_URI}:${GIT_SHA}
          - echo "[CI] write imagedefinitions.json => ${REPO_URI}:${GIT_SHA}"; printf '[{"name":"app","imageUri":"%s"}]' ${REPO_URI}:${GIT_SHA} > imagedefinitions.json
    artifacts:
      files:
        - imagedefinitions.json
    ```

- Approval: Manual gate between CI and CD. Message: "Approve deploy to ECS staging".
- CD (CodePipeline ECS action): Consumes `imagedefinitions.json`, registers a new task definition revision pointing to `<repo>:<git-sha>`, and updates the ECS service; ECS rolls tasks with health checks.

Runbook (copy/paste)

- Env and init (from this lab directory):

  ```bash
  export AWS_PROFILE=devops-sandbox
  export AWS_REGION=ap-southeast-2
  terraform init
  terraform validate && terraform plan
  terraform apply -auto-approve
  ```

- Grab outputs (pipeline + codebuild names):

  ```bash
  PIPELINE_NAME=$(terraform output -raw pipeline_name)
  CODEBUILD_NAME=$(terraform output -raw codebuild_project)
  echo "Pipeline: $PIPELINE_NAME"; echo "CodeBuild: $CODEBUILD_NAME"
  ```

- Start CI (from this lab directory; helper scripts live one level up in `../scripts`):

  ```bash
  EXEC_ID=$(../scripts/codepipeline-start.sh "$PIPELINE_NAME" "$AWS_REGION" "$AWS_PROFILE")
  echo "Execution: $EXEC_ID"
  ```

- Approve (ManualApproval stage):
  - Open the CodePipeline execution in the AWS Console and approve when ready.

- Watch for success:

  ```bash
  ../scripts/verify-pipeline.sh "$PIPELINE_NAME" "$AWS_REGION" "$AWS_PROFILE" "$EXEC_ID"
  ```

- Verify ECS service rollout and current image (requires `jq`):

  ```bash
  ../scripts/verify-ecs.sh devops-refresher-staging app "$AWS_REGION" "$AWS_PROFILE"
  ```

- Probe app health (replace with your ALB DNS or domain):
  ```bash
  ../scripts/verify-app-health.sh https://<alb-dns-or-domain>
  ```

Slack Notifications (optional)

- We typically wire CodePipeline/Build events to a custom Slack notifier Lambda via SNS + CodeStar Notifications.
- See `docs/slack-cicd-integration.md:3` for the architecture and Terraform snippets to attach notifications to this pipeline and the CodeBuild project.

Appendix: Minimal buildspec.yml

Place this at the root of `loftwah/demo-node-app` if you don’t already have one (matches our tagging strategy: staging + git SHA):

```
version: 0.2

env:
  variables:
    IMAGE_REPO_NAME: "demo-node-app"
    APP_ENV: "staging"
  parameter-store:
    AWS_ACCOUNT_ID: "/account/id"

phases:
  install:
    runtime-versions:
      nodejs: 20
    commands:
      - npm ci --no-audit --no-fund
  pre_build:
    commands:
      - npm run build
      - echo Logging in to Amazon ECR...
      - aws --version
      - ACCOUNT_ID=${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}
      - REGION=${AWS_REGION:-${AWS_DEFAULT_REGION:-ap-southeast-2}}
      - REPO_URI=${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${IMAGE_REPO_NAME}
      - aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com
      - GIT_SHA=$(echo ${CODEBUILD_RESOLVED_SOURCE_VERSION} | cut -c1-7)
  build:
    commands:
      - echo Build started on `date`
      - |
        docker build \
          --platform=linux/amd64 \
          -t ${REPO_URI}:staging \
          -t ${REPO_URI}:${GIT_SHA} \
          .
  post_build:
    commands:
      - echo Build completed on `date`
      - docker push ${REPO_URI}:staging
      - docker push ${REPO_URI}:${GIT_SHA}
      - printf '[{"name":"app","imageUri":"%s"}]' ${REPO_URI}:${GIT_SHA} > imagedefinitions.json

artifacts:
  files:
    - imagedefinitions.json
```

Notes:

- The container name `app` in `imagedefinitions.json` must match the container name in your ECS task definition.
- We tag and push both `:staging` (moving) and `:<git-sha>` (immutable). ECS deploy uses the immutable SHA.

Tagging Strategy: staging + git SHA

- Why two tags?
  - `:staging` is a moving alias for quick testing, manual runs, and human-friendly references (also protected in our ECR lifecycle policy).
  - `:<git-sha>` is immutable for precise deployments, rollbacks, and provenance.
- How ECS deploy uses it:
  - Terraform’s base task definition uses `:staging` for initial/manual deploys.
  - CodePipeline’s ECS Deploy action consumes `imagedefinitions.json` and updates the task definition to the exact `:<git-sha>` built in that run.
- Result: Easy manual testing with `:staging`, but actual pipeline deploys are immutable and auditable.

Buildspec Location: App repo vs this repo

- App repo (common):
  - Pros: CI changes version with app changes; developers see build logic alongside code; CodePipeline/CodeBuild default flow is simpler (single source).
  - Cons: Build logic spreads across repos if you have many apps.
- Infra repo (possible):
  - Options: set an inline `buildspec` in the CodeBuild project (Terraform), or add a second source artifact in CodePipeline and point CodeBuild to that path.
  - Pros: Centralized build policy; consistent standards; easier to review in infra PRs.
  - Cons: Tighter coupling to infra deploys; two-repo coordination if the build needs to change with app code.
- Our call: keep buildspec in the app repo for now; we can move to an inline/Terraform-managed buildspec later if we want central control.

Build vs Runtime: Variables & Dependencies

- Build variables (CodeBuild): Inputs used during image build or packaging.
  - Where to set: CodeBuild Project env vars, `buildspec.yml` `env:variables`, `env:parameter-store`, or `env:secrets-manager`.
  - How used: Refer in build steps (`$VAR`), or pass into Docker builds as `--build-arg VAR=$VAR`.
  - Secrets at build time: Avoid Docker `ARG` for secrets (bakes into image layers). Prefer BuildKit secrets.
- Runtime variables (ECS): Values your container needs when running.
  - Where to set: ECS task definition `environment` (non‑secret) and `secrets` (from SSM/Secrets Manager).
  - In this repo: `aws-labs/14-ecs-service` auto-loads from SSM/Secrets Manager via `ssm_path_prefix`, `auto_load_env_from_ssm`, and `auto_load_secrets_from_sm`.

Where to put what

- Put in CodeBuild (build time) when the value only affects building the artifact/image:
  - Example: `NEXT_PUBLIC_*` compile-time flags, private registry token to fetch dependencies, feature flags baked into static assets.
- Put in ECS (runtime) when the app reads it on startup or per request:
  - Example: database endpoint/creds, Redis host, API keys, per‑env secrets.

CodeBuild variable patterns (buildspec)

```
version: 0.2
env:
  variables:
    IMAGE_TAG: ""  # derive from commit when unset
  parameter-store:
    NPM_TOKEN: "/devops-refresher/staging/app/NPM_TOKEN"  # example
phases:
  pre_build:
    commands:
      - export DOCKER_BUILDKIT=1
      - REPO_URI=$(aws ecr describe-repositories --repository-names ${ECR_REPO_NAME} --query 'repositories[0].repositoryUri' --output text)
      - IMAGE_TAG=${IMAGE_TAG:-$(echo ${CODEBUILD_RESOLVED_SOURCE_VERSION} | cut -c1-7)}
  build:
    commands:
      - echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > .npmrc    # if needed
      - docker build \
          --build-arg APP_BUILD_ENV=staging \
          --secret id=npm_token,env=NPM_TOKEN \
          -t ${REPO_URI}:${IMAGE_TAG} .
```

Dockerfile patterns

```
# syntax=docker/dockerfile:1.6
FROM node:20-alpine AS deps
WORKDIR /app
# Non-secret build args are okay as ARG
ARG APP_BUILD_ENV
ENV NODE_ENV=production
COPY package*.json ./
# Example of using a BuildKit secret for NPM token
RUN --mount=type=secret,id=npm_token \
    npm ci --omit=dev

FROM node:20-alpine AS runtime
WORKDIR /app
COPY --from=deps /app /app
EXPOSE 3000
CMD ["node","server.js"]
```

- Use `ARG` for non‑secret build toggles (e.g., `APP_BUILD_ENV`).
- Use BuildKit `--secret` for tokens needed only during `npm ci`/`pip install`.
- Use multi‑stage so build‑time tools never ship in the final image.

ECS runtime variables and secrets

- In `aws-labs/14-ecs-service/main.tf`, runtime values come from:
  - `var.environment`: non‑secret env pairs
  - `var.secrets`: secret refs `{ name, valueFrom }`
  - Auto‑load from SSM/Secrets Manager using:
    - `ssm_path_prefix = "/devops-refresher/staging/app"`
    - `auto_load_env_from_ssm = true`
    - `auto_load_secrets_from_sm = true`
    - `secret_keys = ["DB_PASS", "APP_AUTH_SECRET"]` (example)
- Ensure the container name is `app` to match `imagedefinitions.json`.

Build vs runtime dependencies

- Build-time: compilers, SDKs, headless browsers, devDependencies. Keep them in the builder image or CodeBuild image only.
- Runtime: only production dependencies and minimal base image (e.g., `node:20-alpine`). Use `npm ci --omit=dev` (or `yarn install --production`, or `pnpm install --prod`).
