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
