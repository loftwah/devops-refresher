# Resource Reference & Checklists

Use this as a quick checklist while building. Each section lists required, optional, and validation steps.

## AWS VPC Networking (Simple)

- Required: One VPC (with DNS support), 2+ public subnets, 2+ private subnets, 1 Internet Gateway (IGW), route tables, 1+ NAT Gateway for private egress.
- Optional: One NAT per AZ (HA), VPC Endpoints (SSM/ECR/CloudWatch Logs/S3), Flow Logs, custom NACLs (defaults are fine).

What each thing is for and how it connects

- VPC: Your private network in AWS. Turn on `DNS hostnames` and `DNS support` so services resolve DNS. Everything below lives inside the VPC.
- Availability Zones (AZs): Separate data centers in a region. Put resources across at least two AZs for resilience.
- Public subnets (2+): Subnets that can reach the internet directly. They associate to a route table that sends `0.0.0.0/0` to the IGW. Host internet-facing things like ALB and NAT Gateways.
- Private subnets (2+): Subnets without direct internet. Their route table sends `0.0.0.0/0` to a NAT Gateway in a public subnet so they can download updates, pull images, call APIs, etc. Run ECS tasks/EC2 here.
- Internet Gateway (IGW): Attaches to the VPC. Public subnets route internet-bound traffic to the IGW.
- NAT Gateway (NAT GW): Lives in a public subnet with an Elastic IP. Private subnets send outbound internet traffic to the NAT, which forwards it to the IGW. Use one per AZ for HA; minimum is one NAT (cheaper, less resilient).
- Route tables: Connect subnets to where their traffic goes. Associate public subnets to a route table with default route to IGW; associate private subnets to a route table with default route to NAT.
- VPC Endpoints (optional): Private links to AWS services (no internet/NAT). Common: ECR (api + dkr), SSM, CloudWatch Logs, S3. Reduces NAT costs and increases privacy.
- NACLs (optional): Subnet firewalls. Default allow-all works for most setups; rely on Security Groups for filtering.

Minimum viable layout (2 AZs)

- Subnets: `public-a`, `public-b` in two AZs; `private-a`, `private-b` in the same two AZs.
- IGW: 1 attached to the VPC.
- NAT: 1 total (budget) in one public subnet, or 2 (best) one per AZ. Private subnets should prefer NAT in their own AZ when available.
- Route tables:
  - Public RT: `0.0.0.0/0 -> igw-...`; associated with all public subnets.
  - Private RT(s): `0.0.0.0/0 -> nat-...`; associated with private subnets. With two NATs, use one RT per AZ pointing to that AZ’s NAT.

What connects to what (typical ECS + ALB)

- ALB: Lives in public subnets; has a security group that allows 80/443 from the internet. Targets are ECS tasks in private subnets.
- ECS tasks: Run in private subnets; security group allows inbound only from the ALB’s security group on the app port. For outbound: either NAT to internet or VPC Endpoints to AWS services.
- ECR/Logs/SSM: Reach via NAT (simple) or via VPC Endpoints (private). If you don’t add endpoints, you must have NAT for private subnets.

Validate (spell it out)

- Subnets count/AZ spread: Confirm at least two public and two private subnets across two different AZs.
- Public subnets routing: For each public subnet’s associated route table, check a default route `0.0.0.0/0` to the IGW, and no default to a NAT.
- Private subnets routing: For each private subnet’s route table, check a default route `0.0.0.0/0` to a NAT Gateway, and no route to the IGW.
- NAT placement: NAT lives in a public subnet and has an Elastic IP. If running two NATs, each private subnet should use the NAT in the same AZ.
- IGW attachment: IGW must be in the same VPC and shown as “attached”.
- DNS settings: VPC has DNS Hostnames + DNS Support enabled (needed for ECS/ECR/Docker pulls).
- Connectivity checks:
  - ALB DNS name answers publicly; HTTP→HTTPS redirect works; HTTPS serves valid cert.
  - Target group shows healthy ECS tasks in private subnets.
  - From an ECS task, outbound `curl https://api.ipify.org` returns a public IP (via NAT) unless you restrict egress; if using endpoints, verify pulls to ECR and logs to CloudWatch succeed without internet.
- Reachability Analyzer (optional): Path from ALB SG to ECS task ENI on app port is reachable.
- Costs/HA note: One NAT is cheaper but a single-AZ dependency; two NATs cost more but avoid cross-AZ data charges and single-point NAT failure.

## Security Groups

- Required: ALB SG (80/443 inbound from 0.0.0.0/0), ECS SG (inbound from ALB SG, app port only).
- Optional: Egress lock-down by destination prefix lists; SG referencing SG.
- Validate: Connections via `curl` and AWS reachability analyzer.

## ALB + Target Groups + Listeners

- Required: ALB across public subnets; TG protocol/port/health check; listeners 80→redirect, 443→forward.
- Optional: Listener rules by path/host; WAF; access logs to S3.
- Validate: ALB DNS serves 200; TG shows healthy targets.

## ACM Certificates

- Required: Issued public cert in region of ALB; validation complete.
- Optional: Multi-domain SANs; auto-renew.
- Validate: Listener attaches cert; browser shows valid TLS.

## Route53

- Required: Hosted zone; record (A/AAAA alias) to ALB.
- Optional: Weighted, latency, or failover routing; health checks.
- Validate: `dig` resolves; HTTPS works on hostname.

## ECR

- Required: Repo per app; immutable tags recommended; scan on push.
- Optional: Lifecycle policies (expire old tags); encryption with KMS.
- Validate: Push/pull; image tag resolves in deploy logs.

## IAM

- Required: Task execution role (ECR pull, logs:Create* Put*); Task role (least-privileged runtime permissions).
- Optional: Boundary policies; attribute-based access control via tags.
- Validate: ECS tasks start without permission errors; can fetch params/secrets.

## ECS Cluster / Services / Task Definitions

- Required: Cluster (Fargate); Task definitions (CPU/mem, image, port, env, logs); Service (desired, TG, deployment).
- Optional: Capacity providers; circuit breaker; service autoscaling; exec.
- Validate: Service steady state; targets healthy; logs present.

## Parameters & Secrets

- Required: Parameter Store (SecureString) or Secrets Manager; least-privilege policies.
- Optional: Hierarchical param paths per env/app; rotation for secrets.
- Validate: App reads values; no secrets in TF state or logs.

## CloudWatch

- Required: Log groups per service; metrics dashboards minimal.
- Optional: Alarms for 5XX, latency, CPU/mem; SLOs; synthetic canaries.
- Validate: Logs flowing; alerts fire under induced failures.

## CI/CD (CodePipeline + CodeBuild)

- Required: Build spec (Docker build/push); artifact with image URI; deploy stage updating task definition.
- Optional: Manual approvals; Slack/Webhook notifications; blue/green deploy.
- Validate: Commit triggers build → deploy → healthy service.

## JSON/YAML Cheatsheet

CLI (jq/yq):

- Read JSON value: `jq -r '.user.name' data.json`
- Filter JSON array: `jq -c '.items[] | select(.active==true) | {id, name}' data.json`
- Update JSON and write back: `jq '.limits.cpu = "500m"' config.json > config.json.tmp && mv config.json.tmp config.json`
- Create JSON from scratch: `jq -n --arg env "$ENV" '{app:"web", env:$env, replicas:2}'`
- Read YAML value: `yq '.spec.template.spec.containers[0].image' deploy.yaml`
- Update YAML in place: `yq -i '.metadata.labels.env = "prod"' deploy.yaml`
- Convert YAML→JSON: `yq -o=json '.' deploy.yaml > deploy.json`
- Convert JSON→YAML: `yq -P '.' config.json > config.yaml`

Python:

```python
import json, yaml

# JSON read/write
with open('config.json') as f:
    cfg = json.load(f)
cfg['limits']['cpu'] = '500m'
with open('config.json', 'w') as f:
    json.dump(cfg, f, indent=2)

# YAML read/write
with open('deploy.yaml') as f:
    doc = yaml.safe_load(f)
doc.setdefault('metadata', {}).setdefault('labels', {})['env'] = 'prod'
with open('deploy.yaml', 'w') as f:
    yaml.safe_dump(doc, f, sort_keys=False)
```

Node.js:

```js
const fs = require("fs");
const yaml = require("js-yaml");

// JSON
const cfg = JSON.parse(fs.readFileSync("config.json", "utf8"));
cfg.limits.cpu = "500m";
fs.writeFileSync("config.json", JSON.stringify(cfg, null, 2));

// YAML
const doc = yaml.load(fs.readFileSync("deploy.yaml", "utf8"));
doc.metadata = doc.metadata || {};
doc.metadata.labels = doc.metadata.labels || {};
doc.metadata.labels.env = "prod";
fs.writeFileSync("deploy.yaml", yaml.dump(doc, { noArrayIndent: false }));
```

Bash with jq/yq and env vars:

```bash
ENV=prod IMAGE=example/web:1.2.3

# Insert env/image into YAML (in place)
yq -i \
  '.metadata.labels.env = env(ENV) | .spec.template.spec.containers[0].image = env(IMAGE)' \
  deploy.yaml

# Build JSON payload from env
jq -n --arg env "$ENV" --arg image "$IMAGE" '{env: $env, image: $image}' > payload.json
```

Notes:

- jq is for JSON; yq (mikefarah) handles YAML and JSON and supports in-place `-i` edits.
- For safe in-place JSON edits without `-i`, write to a temp file then move (as shown) or use `moreutils` `sponge` if available.

When/Where/Why to use jq/yq

- Why: Safe, precise structured edits in the shell without fragile grep/sed. Great for quick transforms you can version in scripts and CI.
- Where they shine:
  - CI/CD: bump images, set env, gate releases by reading values; commit minimal, deterministic diffs.
  - API payloads: build JSON for curl/AWS CLI; filter AWS CLI JSON (e.g., instance IDs, ARNs) with jq.
  - K8s/IaC: patch Deployment images/labels with yq; merge base/overlay YAML; convert YAML↔JSON.
  - Data plumbing: `terraform output -json | jq` to feed downstream steps.
  - Logs: pretty-print and filter structured JSON logs in dev/prod.
- How to use effectively:
  - Pipe stdin→stdout; combine with `set -euo pipefail`. For JSON writes, use a temp file, then atomic move; for YAML, prefer `yq -i`.
  - Pass variables safely: jq `--arg name "$NAME"` and yq `env(NAME)`; avoid string interpolation.
  - Merge/patch YAML: `yq eval-all '. as $item ireduce ({}; . * $item)' base.yaml override.yaml` (deep merge).
  - Validate syntax: `jq -e '.' file.json >/dev/null` and `yq e '.' file.yaml >/dev/null` to fail fast in pipelines.
- Common real-world patterns:
  - Filter AWS CLI: `aws ec2 describe-instances | jq -r '.Reservations[].Instances[].InstanceId'`
  - Kubernetes bump image: `yq -i '(.spec.template.spec.containers[] | select(.name=="web").image) = env(IMAGE)' deploy.yaml`
  - Bulk YAML edit: `find k8s -name '*.yaml' -print0 | xargs -0 -I{} yq -i '.metadata.labels.env = env(ENV)' {}`
  - Build JSON for POST: `jq -n --arg tag "$TAG" '{deploy:true, tag:$tag}' | curl -H 'Content-Type: application/json' -d @- https://api.example/deploy`
- When not to use:
  - Complex logic/data flows → write a short Python/Node script for readability/tests.
  - YAML comments/anchors must be preserved → yq may drop comments and can simplify anchors; prefer higher-level tools (Helm/Kustomize) when needed.
  - Schema validation → use domain tools (e.g., `kubeconform`/`kubeval` for K8s, `ajv` for JSON Schema) alongside jq/yq.

## Dockerfile Cheatsheet (Rails-focused)

- Decisions:
  - Base image: `ruby:<version>-slim` (common), `-alpine` (smaller, trickier native builds), distro pinning for repeatability.
  - Multi-stage vs single-stage: multi-stage for production (smaller, safer), single-stage for dev (faster inner loop).
  - Node/npm: needed for asset pipeline/Webpacker; install only where required; consider separate node builder stage.
  - Native deps: list system packages for `pg`, `nokogiri`, etc.; keep build deps out of final image.
  - App user: run as non-root with fixed UID/GID; map in Compose/K8s if needed.
  - Entrypoint & signals: use `tini` or proper ENTRYPOINT/CMD; ensure Puma receives SIGTERM and shuts down gracefully.
  - Caching: order COPYs to maximize cache (Gemfile/Gemfile.lock first). Use BuildKit cache mounts when available.
  - Secrets: no plaintext in Dockerfile; use BuildKit secrets for private gems; runtime secrets via env/SSM.
  - Assets: precompile in build stage; set `RAILS_SERVE_STATIC_FILES=1` in runtime if you serve assets directly.
  - Security: minimal packages, non-root, avoid `latest`, pin versions; scan images; consider read-only FS.

- Multi-stage: Rails production (Puma)

```dockerfile
# syntax=docker/dockerfile:1.7
ARG RUBY_VERSION=3.2

FROM ruby:${RUBY_VERSION}-slim AS base
ENV BUNDLE_WITHOUT="development:test" \
    RAILS_ENV=production \
    RACK_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/bundle
# Common runtime deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 ca-certificates tzdata curl && rm -rf /var/lib/apt/lists/*

FROM base AS builder
# Build deps + node/npm for assets
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git pkg-config libpq-dev nodejs npm && rm -rf /var/lib/apt/lists/*
WORKDIR /app
# Cache gems
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3
# Cache JS deps (npm)
COPY package.json package-lock.json ./
RUN npm ci
# Copy app and build assets
COPY . .
RUN SECRET_KEY_BASE=dummy bundle exec rake assets:precompile

FROM base AS runtime
ENV RAILS_SERVE_STATIC_FILES=1 \
    RAILS_LOG_TO_STDOUT=1 \
    BUNDLE_PATH=/bundle
WORKDIR /app
# Non-root user
RUN useradd -r -u 10001 -g users appuser
# Copy gems and app
COPY --from=builder /bundle /bundle
COPY --from=builder /app /app
# Expose Puma port
EXPOSE 3000
# Minimal healthcheck (customize to your app)
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD curl -f http://localhost:3000/health || exit 1
USER appuser
CMD ["bash","-lc","bundle exec puma -C config/puma.rb"]
```

- Single-stage: Rails development (faster inner loop)

```dockerfile
ARG RUBY_VERSION=3.2
FROM ruby:${RUBY_VERSION}-slim
ENV RAILS_ENV=development RACK_ENV=development \
    BUNDLE_WITHOUT=""
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git pkg-config libpq-dev nodejs npm curl tzdata \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle config set path 'vendor/bundle' \
 && bundle install
COPY package.json package-lock.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["bash","-lc","bin/rails db:prepare && bin/rails server -b 0.0.0.0 -p 3000"]
```

- .dockerignore essentials

```
.git
log
tmp
node_modules
vendor/bundle
spec
test
coverage
Dockerfile*
docker-compose*
.env*
*.sqlite3
storage
public/packs-test
public/packs
public/assets
```

- Build tips
  - Use BuildKit for speed and secrets: `DOCKER_BUILDKIT=1 docker build ...` and `--secret id=...` for private sources.
  - Layer cache: keep Gemfile/Gemfile.lock and package manifests separate and early.
  - Use `ARG` for versions; pin minor versions for reproducible builds.
  - Prefer npm over yarn in 2025; use `npm ci` in production and `npm install` in development.

- Runtime tips
  - Migrations: run as a separate step (entrypoint script or CI/CD step) before starting Puma.
  - Logs: `RAILS_LOG_TO_STDOUT=1` and JSON logging for container platforms.
  - Healthchecks: add `/health` endpoint; ensure graceful shutdown via Puma config.

- Security checklist
  - Non-root user; minimal packages; no shell tools in final image if not needed.
  - Pin base image digests; enable image scanning; keep dependencies updated.
  - Consider read-only filesystem and drop capabilities in orchestrator.

### Variants and Extras

- Alpine variant (npm)

```dockerfile
# syntax=docker/dockerfile:1.7
ARG RUBY_VERSION=3.2
FROM ruby:${RUBY_VERSION}-alpine AS base
ENV BUNDLE_WITHOUT="development:test" RAILS_ENV=production RACK_ENV=production BUNDLE_DEPLOYMENT=1 BUNDLE_PATH=/bundle
RUN apk add --no-cache libpq tzdata nodejs npm

FROM base AS builder
RUN apk add --no-cache build-base git postgresql-dev
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN SECRET_KEY_BASE=dummy bundle exec rake assets:precompile

FROM base AS runtime
WORKDIR /app
RUN adduser -D -u 10001 appuser
COPY --from=builder /bundle /bundle
COPY --from=builder /app /app
EXPOSE 3000
USER appuser
CMD ["bash","-lc","bundle exec puma -C config/puma.rb"]
```

- Nginx reverse proxy (two containers)

Use separate containers: one for Rails (Puma), one for Nginx serving `/public` and proxying `/` to Puma.

```dockerfile
# Nginx Dockerfile
FROM nginx:1.27-alpine
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
# Copy only compiled assets from builder image if using multi-stage builds
COPY --from=builder /app/public /usr/share/nginx/html
```

Example `docker/nginx.conf` (proxy to Puma on rails:3000):

```
server {
  listen 80;
  server_name _;
  root /usr/share/nginx/html;
  try_files $uri @rails;

  location @rails {
    proxy_pass http://rails:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
```

- BuildKit cache mounts (bundler/npm)

```dockerfile
# In builder stage
RUN --mount=type=cache,target=/bundle \
    bundle install --jobs 4 --retry 3

RUN --mount=type=cache,target=/root/.npm \
    npm ci
```
