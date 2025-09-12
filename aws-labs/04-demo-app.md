# Demo App (S3 + Postgres + Redis)

## Objectives

- Provide a minimal Node.js 20 + TypeScript web app demonstrating CRUD across S3, RDS Postgres, and ElastiCache Redis.
- Package once, deploy to both ECS Fargate and EKS using the same repo and image.

## Current Implementation

- Repository: https://github.com/loftwah/demo-node-app
- Self-test: On boot or on-demand, the app performs CRUD against S3, Postgres, and Redis and logs a summary. This validates runtime config, network, and credentials per environment.

## Decisions (Locked)

- Region: `ap-southeast-2` (default across labs)
- Domains:
  - ECS: `demo-node-app-ecs.aws.deanlofts.xyz`
  - EKS: `demo-node-app-eks.aws.deanlofts.xyz`
- Base image: `public.ecr.aws/docker/library/node:20-alpine`
- Healthcheck: `GET /healthz` → `200 ok`
- Endpoints:
  - S3: `POST|GET|DELETE /s3/:id` → `s3://$S3_BUCKET/app/<id>.txt`
  - Postgres: `POST|GET|PUT|DELETE /db/items[/:id]` (table `items`)
  - Redis: `POST|GET|PUT|DELETE /cache/:key`
- Secrets:
  - ECS: task definition environment/secrets (from SSM/Secrets via TF)
  - EKS: Kubernetes Secret or External Secrets (SSM/Secrets Manager)

## Quick Mental Model (What/Why)

- The app is an integration probe. If `/readyz` is ready and `/selftest` passes, your networking (VPC/Subnets/SGs), credentials, and endpoints are wired correctly.
- One repo eliminates drift between ECS and EKS targets. Build once, deploy everywhere.

## Repository Layout (Reference)

```
loftwah/demo-node-app
├─ src/                    # Express server + libs (S3/DB/Redis)
├─ Dockerfile              # Builds production image (+ useful tools for ecs-exec)
├─ buildspec.yml           # CodeBuild: build TS, build+push image, imagedefinitions.json
└─ deploy/eks/chart        # Helm chart (Deployment/Service/Ingress/Secret)
```

## Prerequisites

- Labs completed: VPC, Security Groups, ECR, ALB, ECS Cluster/Service, RDS, ElastiCache, and (optionally) External Secrets Operator for EKS.
- ECR repository: `demo-node-app` in `ap-southeast-2`.
- S3 bucket for app data, e.g., `devops-refresher-staging-app` (exists and accessible).

## What You Do in This Lab

1. Build and push the app image to ECR using CodeBuild (`buildspec.yml`) or the helper script.
2. Wire environment variables and secrets from Terraform outputs/SSM.
3. Deploy to ECS Fargate (primary) and optionally to EKS via Helm.
4. Validate with `/healthz`, `/readyz`, and `/selftest` and exercise CRUD endpoints.

## Tasks (Do These)

1. Clone the repo and inspect.
   - Confirm `Dockerfile`, `buildspec.yml`, and `deploy/eks/chart/` contents match expectations.

2. Build and push an image to ECR.
   - Option A (CI/CodeBuild): use `buildspec.yml` with CodePipeline/CodeBuild.
   - Option B (local): `scripts/push-ecr.sh` pushes `:staging` and `:<git-sha>` to your ECR.

3. Configure runtime env (ECS/EKS).
   - Required env: `APP_ENV`, `LOG_LEVEL`, `S3_BUCKET`, `DB_HOST/PORT/USER/PASS/NAME/SSL`, `REDIS_HOST/PORT[/PASS]`.
   - Set `SELF_TEST_ON_BOOT=false` in cluster deployments; you can trigger on-demand via `/selftest`.

4. Deploy to ECS.
   - Task definition uses `image: <repo>:staging` and exposes port 3000 behind ALB.
   - Secrets injected from SSM/Secrets Manager via Terraform (see parameter-store lab).

5. (Optional) Deploy to EKS with Helm.
   - Use `deploy/eks/chart/values-stub.yaml` and set `image.repository`, DB/Redis endpoints, and secrets.
   - `helm upgrade --install demo-node-app deploy/eks/chart -n demo --create-namespace -f deploy/eks/chart/values-stub.yaml`

6. Validate end-to-end.
   - `GET /healthz` returns `ok`.
   - `GET /readyz` shows service status booleans.
   - `GET /selftest?token=<APP_AUTH_SECRET>` returns `{ s3: {ok}, db: {ok}, redis: {ok} }`.

## Acceptance Criteria (Validate Explicitly)

- Image exists in ECR with tags `staging` and a short git SHA.
- ECS service reaches steady state; ALB target shows healthy on `/healthz`.
- `/readyz` returns `status: ready` once S3, DB, and Redis are reachable.
- `/selftest` returns `ok` for all three services in the deployed environment.
- CRUD endpoints perform write/read/delete for S3, create/get/update/delete for Postgres, and set/get/del for Redis.

## How to Check (Commands)

- Health and readiness:

```bash
curl -s https://demo-node-app-ecs.aws.deanlofts.xyz/healthz
curl -s https://demo-node-app-ecs.aws.deanlofts.xyz/readyz | jq
```

- Self-test (protected):

```bash
curl -s "https://demo-node-app-ecs.aws.deanlofts.xyz/selftest?token=$APP_AUTH_SECRET" | jq
```

- S3 CRUD:

```bash
curl -s -X POST https://demo-node-app-ecs.aws.deanlofts.xyz/s3/demo -H 'Content-Type: application/json' -d '{"text":"hello from AWS"}' | jq
curl -s https://demo-node-app-ecs.aws.deanlofts.xyz/s3/demo
curl -s -X DELETE https://demo-node-app-ecs.aws.deanlofts.xyz/s3/demo | jq
```

- Postgres CRUD:

```bash
curl -s -X POST https://demo-node-app-ecs.aws.deanlofts.xyz/db/items -H 'Content-Type: application/json' -d '{"name":"aws-item","value":{"cloud":true}}' | tee /tmp/item.json
ID=$(jq -r .id /tmp/item.json)
curl -s https://demo-node-app-ecs.aws.deanlofts.xyz/db/items/$ID | jq
curl -s -X PUT https://demo-node-app-ecs.aws.deanlofts.xyz/db/items/$ID -H 'Content-Type: application/json' -d '{"name":"aws-item-2","value":{"updated":true}}' | jq
curl -s -X DELETE https://demo-node-app-ecs.aws.deanlofts.xyz/db/items/$ID | jq
```

- Redis CRUD:

```bash
curl -s -X POST https://demo-node-app-ecs.aws.deanlofts.xyz/cache/ping -H 'Content-Type: application/json' -d '{"value":"hello aws"}' | jq
curl -s https://demo-node-app-ecs.aws.deanlofts.xyz/cache/ping
curl -s -X DELETE https://demo-node-app-ecs.aws.deanlofts.xyz/cache/ping | jq
```

## Troubleshooting

- Health checks failing: confirm target group path `/healthz`, port mapping `3000:3000`, and security groups (ALB → service).
- S3 errors: verify `S3_BUCKET` exists and task/pod role has S3 permissions; if using MinIO locally, set `S3_ENDPOINT` and `S3_FORCE_PATH_STYLE=true`.
- DB SSL mismatch: set `DB_SSL=required|disable` to match RDS config; ensure SG allows from ECS tasks.
- Redis TLS: set `REDIS_TLS=true` for ElastiCache in-transit encryption; optionally provide `REDIS_PASS/REDIS_USERNAME`.
- Self-test on boot: disable in clusters via `SELF_TEST_ON_BOOT=false`; run on-demand with `/selftest`.

## References

- App repo: `loftwah/demo-node-app`
- Buildspec: `buildspec.yml` in the app repo
- Helm chart: `deploy/eks/chart` in the app repo
- Related labs: ECR (03), RDS (09), ElastiCache (10), Parameter Store (11), ALB (12), ECS Cluster (13), ECS Service (14)
