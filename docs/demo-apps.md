# Demo Applications – Requirements and Conventions

## Current Implementation

- Repository: https://github.com/loftwah/demo-node-app
- Behavior: On startup, the app runs a self-test that exercises CRUD against S3, Postgres, and Redis, logging results to STDOUT. This validates connectivity, credentials, and basic data operations in each backing service.

We deploy a single Node.js demo app to both ECS and EKS under different domains that match repository names:

- ECS: `demo-node-app-ecs.aws.deanlofts.xyz`
- EKS: `demo-node-app-eks.aws.deanlofts.xyz`

Expectations

- Container: Node.js 20 (alpine) recommended; expose `PORT` (default 3000)
- Health: `GET /healthz` returns 200 quickly
- Logging: write to STDOUT
- Config (non-secrets): from SSM Parameter Store
  - Keys: `/devops-refresher/staging/app/APP_ENV`, `/.../S3_BUCKET`
  - Read on startup; tolerate missing optional keys
- Secrets: from AWS Secrets Manager (later labs)
- S3 demo: exposes `/s3/test` to write/read a test object in your app bucket/prefix

Repo options

- Preferred: one repo `loftwah/demo-node-app` with two deploy targets (ECS/EKS)
- Alternative: split repos `loftwah/demo-node-app-ecs` and `loftwah/demo-node-app-eks` only if teams, cadence, or compliance boundaries require it

Dockerfile baseline

```
FROM public.ecr.aws/docker/library/node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
ENV PORT=3000
EXPOSE 3000
CMD ["node","server.js"]
```

Configuration

- Build vs runtime: see `docs/build-vs-runtime-config.md` for when to use Docker build args vs container env/secrets, and how to wire them in this repo.
- Runtime env (non-secrets): `APP_NAME`, `APP_ENV`, `S3_BUCKET`; override per environment in ECS task definition (`aws-labs/05-ecs/main.tf:176`).
- Runtime secrets: inject via ECS task `secrets` from SSM/Secrets Manager; task role already permits SSM path reads.
- Optional: logging level and feature flags, e.g., `LOG_LEVEL`, `FEATURE_X_ENABLED`.

ECS specifics

- Task role: read SSM path `/devops-refresher/staging/app/*`, RW to `s3://<bucket>/app/*`
- Logs: awslogs driver to CloudWatch Logs
- ALB healthcheck path: `/healthz`

EKS specifics

- IRSA role: same SSM and S3 permissions
- Ingress: ALB via aws-load-balancer-controller, external-dns for Route53
- Helm: values for `image.repository`, `image.tag`, `service.port`, `ingress.host`

CloudFront

- One distribution per app, DNS via Route 53 aliases
- TLS: ACM in us-east-1

## Build Secrets & Config Walkthroughs (No App Code Here)

We keep demo application code in external repos (e.g., `loftwah/demo-node-app`). This section defines what to walk through in those repos to demonstrate correct handling of build-time vs runtime configuration and modern Docker BuildKit secrets. It avoids embedding code or CI here and instead references patterns and examples.

References

- Build vs runtime guide: `docs/build-vs-runtime-config.md`
- BuildKit secret examples (npm, Yarn, Vite, Rails/Webpacker, Bundler): `docs/build-secrets-examples.md`

What to demonstrate (per demo)

- Build-time inputs are non-secret and influence the image only (e.g., `COMMIT_SHA`).
- Runtime config (non-secrets) provided by ECS/EKS manifests and overridable per environment.
- Runtime secrets sourced from SSM/Secrets Manager via the orchestrator, not baked into images.
- Build-time secrets provided using BuildKit secret mounts, never via `ARG`.

Suggested demo flow (shared template)

1. Discover config
   - Show `ARG`/`ENV` in the Dockerfile (build-time vs runtime defaults).
   - Grep app code for env lookups (e.g., `process.env.X`, `ENV["X"]`).
   - Point to ECS task `environment`/`secrets` definitions in Terraform.
2. Build with Buildx
   - Use `docker buildx build ...` with `--build-arg COMMIT_SHA=...` (non-secret) and `--secret id=...` for any private dependency access.
   - Verify post-build: `docker history` shows no secrets; no `.npmrc` or auth files persist in layers.
3. Runtime injection
   - Show how non-secrets and secrets are provided at runtime (ECS `environment`/`secrets`, EKS `env`/CSI driver -> Secret -> `envFrom`).
   - Note architecture: ECS Fargate tasks set `runtime_platform.cpu_architecture` to `ARM64` or `X86_64`. Ensure image matches, or publish a multi‑arch tag.
4. Validate behavior
   - App starts with correct env; secrets accessible only at runtime. Logs confirm SSM/Secrets Manager reads; no hardcoded secrets.

Ecosystem-specific outlines (use external repos for code):

- npm (private registry)
  - Build: `--secret id=npm_token,env=NPM_TOKEN` with a temporary `.npmrc` during `npm ci`.
  - Runtime: environment variables like `PORT`, `NODE_ENV`, non-secrets from SSM; secrets via ECS task `secrets`.
  - Evidence: `docker history` sanitised; container starts with `NODE_ENV` from runtime.

- Yarn
  - Build: reuse npm token via temp `.npmrc`; `yarn install --frozen-lockfile`.
  - Runtime: same as npm.
  - Evidence: no `.npmrc` in final image; layer diff is clean.

- Vite (frontend)
  - Build: optional npm token secret only for dependency install; `npm run build` to produce `/dist` and serve with Nginx.
  - Runtime: static files only; no secrets needed at runtime unless proxied API requires env for base URLs.
  - Evidence: final image contains only `/usr/share/nginx/html` assets; no secret files.

- Rails + Webpacker
  - Build: Bundler with `--mount=type=secret,id=bundle_config`; Yarn/npm with optional npm token secret; `assets:precompile` with `SECRET_KEY_BASE=dummy`.
  - Runtime: Rails runtime env (e.g., `RAILS_LOG_TO_STDOUT`, database URL), secrets via ECS task `secrets`/EKS Secret.
  - Evidence: no `/root/.bundle/config` or `.npmrc` in final image; Puma starts and serves compiled assets.

- Bundler-only (gems)
  - Build: `RUN --mount=type=secret,id=bundle_config,target=/root/.bundle/config bundle install`.
  - Runtime: application env and secrets injected by orchestrator.
  - Evidence: gems available; no bundler config in layers.

Operational checklist for demos

- Use Buildx and the `# syntax=docker/dockerfile:1.7` header in Dockerfile.
- For ARM vs x86: either build single‑arch images with `--platform linux/arm64|linux/amd64` to match Fargate, or publish multi‑arch manifests with `--platform linux/amd64,linux/arm64`.
- Never pass secrets via `ARG` or commit them; prefer `--secret` or `--ssh` for private Git.
- Confirm IAM for runtime secret access (task role/IRSA) before running the demo.
- Show negative test: remove a runtime secret and demonstrate startup failure with a clear error message.

CI/CD notes (kept in external repos)

- GitHub Actions: use `docker/build-push-action@v6` with `secrets:` (see `docs/build-secrets-examples.md`).
- CodeBuild: use Parameter Store to source ephemeral tokens and pass to BuildKit via `--secret` rather than `--build-arg`.
