# Demo App Lab (Usage + Validation)

This lab uses the application in [loftwah/demo-node-app](https://github.com/loftwah/demo-node-app). It demonstrates CRUD across S3, RDS Postgres, and ElastiCache Redis and is deployed to ECS (and optionally EKS).

## Quickstart

1. Build and push image to ECR (local helper):

```bash
cd <cloned app repo>
bash aws-labs/scripts/push-ecr.sh
```

2. Deploy via Terraform (ECS service uses `:staging` by default).

3. Hit health/readiness:

```bash
curl -s https://demo-node-app-ecs.aws.deanlofts.xyz/healthz
curl -s https://demo-node-app-ecs.aws.deanlofts.xyz/readyz | jq
```

## Endpoints

- `GET /healthz` → liveness (200 OK)
- `GET /readyz` → readiness JSON with S3/DB/Redis statuses
- `GET /selftest` → runs end-to-end CRUD across S3, DB, Redis (protected)
- S3 CRUD: `POST|GET|DELETE /s3/:id`
- DB CRUD: `POST|GET /db/items`, `GET|PUT|DELETE /db/items/:id`
- Redis CRUD: `POST|GET|PUT|DELETE /cache/:key`

## Authentication for protected routes

Use either:

- Query: `?token=<APP_AUTH_SECRET>`
- Header: `Authorization: Bearer <APP_AUTH_SECRET>`

Example:

```
https://demo-node-app-ecs.aws.deanlofts.xyz/selftest?token=<APP_AUTH_SECRET>
```

Expected success shape:

```json
{
  "s3": { "ok": true, "bucket": "<bucket>", "key": "app/selftest-<ts>.txt" },
  "db": { "ok": true, "id": "<uuid>" },
  "redis": { "ok": true, "key": "selftest:<uuid>" }
}
```

## Configuration (env)

- `APP_ENV` (default `staging`), `LOG_LEVEL`, `PORT=3000`
- `S3_BUCKET`
- `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASS`, `DB_NAME`, `DB_SSL=required|disable`
- `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASS`, `REDIS_TLS`
- `SELF_TEST_ON_BOOT` (default `true`; set `false` for clusters)

## Local development (Docker Compose)

```bash
docker compose up --build -d
curl -s localhost:3000/healthz
curl -s localhost:3000/readyz | jq
```

Exercise CRUD locally (examples):

```bash
curl -s -X POST localhost:3000/s3/banana -H 'Content-Type: application/json' -d '{"text":"hello"}' | jq
curl -s localhost:3000/s3/banana
curl -s -X DELETE localhost:3000/s3/banana | jq
```

## ECS buildspec (CI/CD)

`buildspec.yml` compiles TypeScript, builds a Docker image, tags it with `staging` and the short git SHA, pushes to ECR, and emits `imagedefinitions.json` for ECS.

## EKS (optional)

Helm chart lives at `deploy/eks/chart` in the app repo. Use `values-stub.yaml` as a starting point and set `image.repository`, DB/Redis endpoints, and secrets. Example:

```bash
helm upgrade --install demo-node-app deploy/eks/chart \
  --namespace demo --create-namespace \
  -f deploy/eks/chart/values-stub.yaml
```

## Validation on AWS

Replace `<domain>` with the ECS/EKS domain.

```bash
# S3
curl -s -X POST https://<domain>/s3/demo -H 'Content-Type: application/json' -d '{"text":"hello from AWS"}' | jq
curl -s https://<domain>/s3/demo
curl -s -X DELETE https://<domain>/s3/demo | jq

# Postgres
curl -s -X POST https://<domain>/db/items -H 'Content-Type: application/json' -d '{"name":"aws-item","value":{"cloud":true}}' | tee /tmp/aws-item.json
ID=$(jq -r .id /tmp/aws-item.json)
curl -s https://<domain>/db/items/$ID | jq
curl -s -X PUT https://<domain>/db/items/$ID -H 'Content-Type: application/json' -d '{"name":"aws-item-2","value":{"updated":true}}' | jq
curl -s -X DELETE https://<domain>/db/items/$ID | jq

# Redis
curl -s -X POST https://<domain>/cache/ping -H 'Content-Type: application/json' -d '{"value":"hello aws"}' | jq
curl -s https://<domain>/cache/ping
curl -s -X DELETE https://<domain>/cache/ping | jq
```

## Links

- App repo: [demo-node-app](https://github.com/loftwah/demo-node-app)
- GHCR images (optional CI): https://github.com/loftwah/demo-node-app/pkgs/container/demo-node-app
