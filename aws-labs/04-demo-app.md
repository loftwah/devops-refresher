# Demo App Setup (Single Repo + Buildspecs)

## Objective

Create a minimal TypeScript Node.js 20 web app demonstrating CRUD across S3, RDS Postgres, and ElastiCache Redis, packaged for both ECS and EKS from a single repository.

## Current Implementation

- Repository: https://github.com/loftwah/demo-node-app
- Self-test: On boot, the app executes a self-test routine that performs CRUD operations against S3, Postgres, and Redis, and logs the outcomes. This provides immediate validation of runtime configuration, network access, and credentials in each environment.

## Repo strategy (single repo)

```
loftwah/demo-node-app
├─ src/
├─ Dockerfile
├─ package.json
├─ tsconfig.json
├─ buildspec.yml           # ECS build (CodeBuild)
├─ deploy/
│  ├─ ecs/                # task/service notes or IaC (optional)
│  └─ eks/
│     └─ chart/           # Helm chart (Deployment/Service/Ingress/Secret)
└─ docs/
   └─ buildspecs/buildspec-ecs.yml (optional template source)
```

## Decisions

- Domains:
  - ECS: `demo-node-app-ecs.aws.deanlofts.xyz`
  - EKS: `demo-node-app-eks.aws.deanlofts.xyz`
- Base image: `public.ecr.aws/docker/library/node:20-alpine`
- Healthcheck: `GET /healthz` → `{ status:"ok", version, services }`
- CRUD Endpoints:
  - S3: `POST|GET|DELETE /s3/:id` at `s3://$S3_BUCKET/app/<id>.txt`
  - Postgres: `POST|GET|PUT|DELETE /db/items[/:id]` (table: `items(id uuid pk, name text, value jsonb, created_at timestamptz default now())`)
  - Redis: `POST|GET|PUT|DELETE /cache/:key`
- Config (env):
  - Common: `APP_ENV` (default `staging`), `LOG_LEVEL`, `PORT=3000`
  - S3: `S3_BUCKET`
  - Postgres: `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASS`, `DB_NAME`, `DB_SSL=required|disable`
  - Redis: `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASS`
- Secrets delivery:
  - ECS: Task Definition secrets
  - EKS: Kubernetes Secrets or CSI (Secret Store)

## Files to create

Shared for ECS/EKS:

- `package.json` (scripts: `build`, `start`, `lint`)
- `tsconfig.json`
- `src/server.ts` (Express):
  - `GET /healthz` (checks S3 headBucket, DB connect, Redis ping)
  - S3 CRUD: `POST|GET|DELETE /s3/:id`
  - DB CRUD: `POST|GET|PUT|DELETE /db/items[/:id]` using `pg`
  - Redis CRUD: `POST|GET|PUT|DELETE /cache/:key` using `ioredis`
- `src/lib/aws.ts` (S3 client v3), `src/lib/db.ts` (pg pool + boot migration), `src/lib/redis.ts` (ioredis)
- `Dockerfile` (compile TS, prune dev deps)
- `.dockerignore` (`node_modules`, `dist`, `.git`, `logs`)
- `buildspec.yml` (npm ci → build TS → docker build/push → `imagedefinitions.json`)

EKS only:

- `deploy/eks/chart/Chart.yaml`
- `deploy/eks/chart/values.yaml`
- `deploy/eks/chart/templates/deployment.yml` (probes on `/healthz`)
- `deploy/eks/chart/templates/service.yml`
- `deploy/eks/chart/templates/ingress.yml` (ALB annotations; host: `demo-node-app-eks.aws.deanlofts.xyz`)
- `deploy/eks/chart/templates/secret.yml` (or CSI objects)

## Dockerfile

```
FROM public.ecr.aws/docker/library/node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev
ENV PORT=3000
EXPOSE 3000
CMD ["node","dist/server.js"]
```

## Buildspec (ECS) — summary

Install deps → build TS → docker build/tag `:staging` and `:<git-sha>` → push → emit `imagedefinitions.json`.

## Helm (EKS)

- `values.yaml`: `image.repository`, `image.tag`, `service.port=3000`, `ingress.host=demo-node-app-eks.aws.deanlofts.xyz`, env/secret refs.
- Deployment: liveness/readiness probes on `/healthz` with sensible thresholds.

## Minimal DB migration

- On boot, if `items` missing, create it. Optional `SEED_DB=true` to insert demo rows.

## Suggested Cursor prompt

```
Generate a minimal TypeScript (Node 20, Express) web app with Docker and a Helm chart.

Requirements:
- Endpoints:
  - GET /healthz → {status:"ok",version,services}
  - S3 CRUD at s3://$S3_BUCKET/app/<id>.txt using AWS SDK v3 (S3Client)
  - Postgres CRUD (table items: id uuid, name text, value jsonb, created_at timestamptz) using pg
  - Redis CRUD using ioredis
- Env: APP_ENV (default "staging"), LOG_LEVEL, PORT=3000,
       S3_BUCKET,
       DB_HOST, DB_PORT, DB_USER, DB_PASS, DB_NAME, DB_SSL,
       REDIS_HOST, REDIS_PORT, REDIS_PASS
Files:
- package.json (scripts: build, start, lint)
- tsconfig.json
- src/server.ts and src/lib/{aws.ts,db.ts,redis.ts}
- Dockerfile (npm ci -> tsc -> prune dev -> node dist/server.js)
- .dockerignore (node_modules, dist, .git, logs)
- buildspec.yml (build TS, docker build/push, imagedefinitions.json)
- deploy/eks/chart with Deployment/Service/Ingress/Secret; probes on /healthz
```

## Notes

- One repo keeps ECS and EKS deploy targets in sync and avoids code drift. Split only if teams or compliance require.
