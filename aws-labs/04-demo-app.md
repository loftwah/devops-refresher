# Lab 04: Demo App Setup (Repositories + Buildspecs)

## Objective

Create demo application repositories that match our naming and domain conventions, ready for ECS and EKS pipelines.

## Decisions

- Repos:
  - `loftwah/demo-node-app-ecs`
  - `loftwah/demo-node-app-eks`
- Domains:
  - ECS: `demo-node-app-ecs.aws.deanlofts.xyz`
  - EKS: `demo-node-app-eks.aws.deanlofts.xyz`
- Base image: `public.ecr.aws/docker/library/node:20-alpine`
- Healthcheck: `GET /healthz` returns 200 with version JSON
- S3 proof: `GET /s3/test` writes then reads an object at `s3://$S3_BUCKET/app/health/<ts>.txt`
- Config: via env vars (injected by ECS task def or EKS secrets/CSI)

## Files to Create

In each repo:

- `package.json` with scripts: `start`, `lint`
- `server.js` (Express app with `/healthz` and `/s3/test` using AWS SDK v3)
- `Dockerfile` (see below)
- `.dockerignore` (node_modules, .git, logs)
- `buildspec.yml` (copy from `docs/buildspecs/buildspec-ecs.yml` for the ECS repo)
- For EKS repo: add a `chart/` directory with Helm chart (Deployment, Service, Ingress)

## Dockerfile

```
FROM public.ecr.aws/docker/library/node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
ENV PORT=3000
EXPOSE 3000
CMD ["node","server.js"]
```

## Buildspec (ECS)

Use `docs/buildspecs/buildspec-ecs.yml` as `buildspec.yml` in the ECS repo. It builds and pushes `:staging` and `:<git-sha>` and emits `imagedefinitions.json` for ECS deploy.

## Helm (EKS)

- Chart values: `image.repository`, `image.tag`, `service.port=3000`, `ingress.host=demo-node-app-eks.aws.deanlofts.xyz`
- Probes on `/healthz`

## Suggested Cursor Prompt

Copy this into Cursor (or similar) to scaffold the repo:

```
Generate a minimal Node.js 20 (alpine) web app with Docker and (for EKS) a Helm chart.
Requirements:
- Endpoints: GET /healthz returns {status:"ok",version}; GET /s3/test writes+reads to s3://$S3_BUCKET/app/health/<ts>.txt
- Env: APP_ENV (default "staging"), S3_BUCKET (required), LOG_LEVEL (optional)
- Logging: stdout; PORT=3000
Files:
- package.json (scripts: start)
- server.js (Express; use AWS SDK v3 S3Client)
- Dockerfile (node:20-alpine; npm ci; CMD node server.js)
- .dockerignore (node_modules, .git, logs)
- buildspec.yml (use the provided buildspec-ecs.yml template logic)
- chart/ (for EKS): Chart.yaml, values.yaml, templates/deployment.yaml, service.yaml, ingress.yaml with ALB annotations
```

## Next

- Create the repos and push initial code.
- Pass `github_full_repo_id` to the CI/CD lab when wiring pipelines.
- ECS pipeline: builds and deploys to the ECS service.
- EKS pipeline (later): kubectl/helm deploy using the EKS buildspec.
