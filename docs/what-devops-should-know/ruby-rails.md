# What A Senior DevOps Engineer Should Know About Ruby and Ruby on Rails (2025)

Ruby and Rails continue to power serious production systems in 2025. As a Senior DevOps engineer, you do not need to be a full-time Rails dev, but you do need to understand the stack well enough to build, containerise, run, debug, scale, and deploy it with confidence. This doc focuses on practical operation: how Ruby works, how Rails is structured, how Sidekiq uses Redis, how to design images for development and production, and how to run the whole thing reliably on AWS.

This guide assumes Ruby 3.4.x and Rails 7.2 or 8.0, which are current and supported. Ruby 3.4.5 is the latest stable on the official releases list. Rails 7.2 and 8.0 release notes are available in the guides. Puma remains the default app server, Sidekiq the most common job runner, and Redis the de facto queue store. ([Ruby][1], [Ruby on Rails Guides][2], [Heroku Dev Center][3], [Ruby on Rails API][4])

---

## Why this stack still matters

- Many high-traffic SaaS products still run Rails. You will encounter Rails at some point, even if your day job is Go or Node.
- Rails excels at internal tools and admin backends for ops teams.
- The ecosystem is stable and well documented. Most tasks have a known good path, which is exactly what you want in prod.

---

## Ruby in one page for DevOps

Ruby is dynamically typed, and everything is an object. That means methods like `to_s` exist on numbers, booleans, and strings, and that configuration and results are passed around as objects.

```ruby
region   = "ap-southeast-2"  # String
replicas = 3                  # Integer
logging  = true               # TrueClass

[region, replicas, logging].map(&:class)
# => [String, Integer, TrueClass]
```

Error handling uses exceptions. Scripts should exit with the right code for CI.

```ruby
def risky
  raise "network flake" if rand > 0.5
  "ok"
end

begin
  puts risky
  exit 0
rescue => e
  warn "FAIL: #{e.message}"
  exit 1
end
```

---

## Rails mental model

Rails is a batteries-included web framework. Convention over configuration gives you predictable file layout and runtime behaviour, which is handy for ops.

```
app/
  controllers/     # HTTP endpoints
  models/          # Active Record ORM objects
  views/           # templates (or API serializers)
  jobs/            # background work via Active Job
config/
  environments/    # dev, test, prod configs
  puma.rb          # app server settings
  sidekiq.yml      # Sidekiq concurrency and queues
db/
  migrate/         # schema migrations
Gemfile            # dependencies
```

Active Job is the Rails abstraction for background jobs. You pick an adapter. For production use Sidekiq, which uses Redis under the hood. Set the adapter to `:sidekiq` or Rails falls back to the `:async` inline executor in the app process. ([Ruby on Rails API][4], [GitHub][5])

---

## Sidekiq and Redis in plain English

- Sidekiq stores queued jobs, schedules, and metadata in Redis.
- In development it connects to `redis://localhost:6379` by default. In production you should point it at a managed Redis, usually ElastiCache for Redis, and enable TLS (`rediss://`). ([GitHub][6], [Amazon Web Services, Inc.][7])
- Sidekiq runs workers in threads, so one process can execute multiple jobs at once. Configure concurrency carefully, because each thread needs DB and Redis connections. ([Ruby on Rails API][8])

Minimal Sidekiq config with Redis URL and concurrency:

```yaml
# config/sidekiq.yml
:concurrency: <%= ENV.fetch("SIDEKIQ_CONCURRENCY", "10") %>
:queues:
  - default
  - mailers
  - critical
:timeout: 30
```

Initialiser that wires Rails + Sidekiq + Redis:

```ruby
# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL") } # e.g. rediss://...
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL") }
end
```

Tell Rails to use Sidekiq:

```ruby
# config/application.rb
config.active_job.queue_adapter = :sidekiq
```

Active Job worker and how to call it:

```ruby
# app/jobs/deploy_job.rb
class DeployJob < ApplicationJob
  queue_as :critical

  retry_on(StandardError, attempts: 5, wait: :exponentially_longer)

  def perform(service, replicas)
    Rails.logger.info "Deploying #{service} with #{replicas} replicas"
    # do work here
  end
end

# enqueue from controller, rake task, or console
DeployJob.perform_later("web", 3)
```

Sidekiq uses Redis reliably, but production clusters should follow ElastiCache best practices on connectivity, TLS, node types, and scaling. ([AWS Documentation][9])

---

## Puma in production

Puma is a multi-threaded application server. You scale using a mix of threads and worker processes. The safe path is fewer workers, small thread pool, and measure. The Rails 7.2 defaults improved thread count choices, and the Heroku guide explains concurrency trade-offs clearly. ([Ruby on Rails Guides][2], [Heroku Dev Center][3])

`config/puma.rb` tuned for containers:

```ruby
# config/puma.rb
max_threads = Integer(ENV.fetch("RAILS_MAX_THREADS", 5))
min_threads = Integer(ENV.fetch("RAILS_MIN_THREADS", max_threads))
threads min_threads, max_threads

workers Integer(ENV.fetch("WEB_CONCURRENCY", 2))
preload_app!

port ENV.fetch("PORT", 3000)
environment ENV.fetch("RAILS_ENV", "production")

# Allow health checks without log noise
lowlevel_error_handler do |ex, env|
  Rails.logger.error(ex)
  [500, {}, ["error"]]
end
```

---

## Logging correctly in containers

Log to STDOUT so logs land in CloudWatch, Datadog, or your aggregator. Rails supports STDOUT logging via config and the `RAILS_LOG_TO_STDOUT` convention. For container platforms this avoids filling the filesystem with `log/*.log`. ([werf.io][10], [BigBinary][11])

```ruby
# config/environments/production.rb
config.log_level = :info
if ENV["RAILS_LOG_TO_STDOUT"].present?
  logger           = ActiveSupport::Logger.new($stdout)
  logger.formatter = config.log_formatter
  config.logger    = ActiveSupport::TaggedLogging.new(logger)
end
```

---

## Credentials and secrets

Use `rails credentials:edit` for app secrets, but do not bake the master key into images. Supply it at runtime through `RAILS_MASTER_KEY` from AWS Secrets Manager or SSM Parameter Store. The Rails security guide documents the mechanism. ([Ruby on Rails Guides][12])

---

## Dev and prod containers the right way

You want fast rebuilds and a pleasant dev loop locally, and you want small, secure, reproducible images in prod. Use **two Dockerfiles** or one Dockerfile with **multi-stage** targets that diverge for dev and prod. Multi-stage cuts image size and build time. ([Nick Janetakis][13])

### Dev image

- Includes build tools and useful gems
- Mounts source code
- Runs Rails and Sidekiq as separate services in Compose
- Uses Postgres and Redis containers

```dockerfile
# Dockerfile.dev
FROM ruby:3.4-slim

# System deps for PostgreSQL, bundler, and node-less CSS/JS (use importmap or esbuild if needed)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git libpq-dev curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Cache bundler layer
COPY Gemfile Gemfile.lock ./
RUN bundle config set without 'production' \
 && bundle install --jobs=4

# App code mounted in compose, but copy bin to ensure bin/rails exists
COPY bin/ ./bin/
ENV PATH="/app/bin:${PATH}"

# Default dev command is in compose
```

Compose file for development:

```yaml
# docker-compose.dev.yml
services:
  web:
    build:
      context: .
      dockerfile: Dockerfile.dev
    command: bin/rails server -b 0.0.0.0 -p 3000
    volumes:
      - .:/app
    environment:
      RAILS_ENV: development
      DATABASE_URL: postgres://postgres:postgres@db:5432/app_dev
      REDIS_URL: redis://redis:6379/0
      RAILS_LOG_TO_STDOUT: "1"
    ports: ["3000:3000"]
    depends_on: [db, redis]
  worker:
    build:
      context: .
      dockerfile: Dockerfile.dev
    command: bundle exec sidekiq -C config/sidekiq.yml
    volumes:
      - .:/app
    environment:
      RAILS_ENV: development
      DATABASE_URL: postgres://postgres:postgres@db:5432/app_dev
      REDIS_URL: redis://redis:6379/0
      RAILS_LOG_TO_STDOUT: "1"
    depends_on: [db, redis]
  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: app_dev
    ports: ["5432:5432"]
  redis:
    image: redis:7
    ports: ["6379:6379"]
```

Run it locally:

```bash
docker compose -f docker-compose.dev.yml up --build
# Web on http://localhost:3000, Sidekiq UI if you mount it at /sidekiq
```

If you prefer a reference sample for Rails + Compose, Docker maintains one. ([Docker Documentation][14])

### Production image

- Multi-stage, small runtime
- Non-root user
- Assets precompiled
- Only production gems

```dockerfile
# Dockerfile
# 1) builder stage
FROM ruby:3.4-slim AS builder
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git libpq-dev \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app

ENV RAILS_ENV=production
COPY Gemfile Gemfile.lock ./
RUN bundle config set deployment 'true' \
 && bundle config set without 'development test' \
 && bundle install --jobs=4

COPY . .
# If using asset pipeline or jsbundling-rails, precompile here
RUN bundle exec rake assets:precompile

# 2) runtime stage
FROM ruby:3.4-slim
RUN useradd -m app
WORKDIR /app
COPY --from=builder /usr/local/bundle/ /usr/local/bundle/
COPY --from=builder /app /app
USER app

ENV RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=1 \
    PORT=3000

EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

Multi-stage guidance for Rails is well known and reduces image size substantially. ([Nick Janetakis][13], [whittakertech.com][15])

---

## How to call things, and how you see success or failure

### Local commands

```bash
# migrations
docker compose -f docker-compose.dev.yml run --rm web bin/rails db:migrate

# run a job
docker compose -f docker-compose.dev.yml exec web bin/rails runner "DeployJob.perform_later('web', 3)"

# view worker logs
docker compose -f docker-compose.dev.yml logs -f worker
```

Success means exit code 0 and the expected log output. Failure means non-zero exit or exceptions logged. Both web and worker log to STDOUT so your platform can aggregate logs. ([werf.io][10])

### API success and failure

In controllers return correct HTTP codes:

```ruby
class ServersController < ApplicationController
  def show
    server = Server.find(params[:id])
    render json: server, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: "not found" }, status: :not_found
  end
end
```

### Job success and failure

Sidekiq will retry jobs automatically using its retry strategy. You can declare retries on the job class and you will see failures in the Sidekiq Web UI. ([Ruby on Rails API][8])

---

## AWS deployment patterns that work

You have three practical paths in 2025.

### ECS Fargate

Good default for most Rails apps. You run a web service and a worker service from the same image tag.

- Web service: Rails + Puma behind an ALB
- Worker service: Sidekiq process with the same image
- RDS for Postgres
- ElastiCache for Redis with TLS (`rediss://...`)
- CloudWatch Logs for STDOUT from both services
- Secrets via Secrets Manager or SSM, injected as env vars
- ECR hosts images, CI pushes on merge

Follow ECS best practices for networking, task permissions, health checks, and capacity. ([AWS Documentation][16])

### EKS

Choose EKS if you already have strong Kubernetes investment.

- Deployment for web, HorizontalPodAutoscaler for traffic
- Deployment or StatefulSet for Sidekiq workers with separate queues
- ServiceAccount and IAM Roles for Service Accounts
- RDS and ElastiCache as AWS managed attachments
- cdk8s or Helm for manifests

Rails on Kubernetes is common, but requires platform maturity.

### App Runner

Works well when you want a fully managed container platform with load balancing, TLS, autoscaling, and logs, but not the full power of ECS. App Runner supports running containerised Rails apps, and receives periodic runtime updates that include Ruby platform updates. ([AWS Documentation][17])

---

## Continuous Integration and Delivery

GitHub Actions example that builds, tests, and pushes a container:

```yaml
name: ci
on:
  push:
    branches: [main]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: "3.4"
          bundler-cache: true
      - run: bundle exec rake db:schema:load
      - run: bundle exec rake
      - name: Build image
        run: docker build -t ${{ github.sha }} .
      - name: Push to ECR (example)
        run: |
          echo "login and push steps here using aws-actions/amazon-ecr-login"
```

You would follow with an ECS deploy step (CodeDeploy or `aws ecs update-service`) or an App Runner deploy step, depending on your platform.

---

## A minimal reference app you can lift

Gemfile essentials:

```ruby
# Gemfile
ruby "3.4.5"

gem "rails", "~> 7.2.0" # or "~> 8.0"
gem "pg"
gem "puma"
gem "redis"
gem "sidekiq"

group :development, :test do
  gem "rspec-rails"
end
```

Routes and Sidekiq dashboard:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  require "sidekiq/web"
  mount Sidekiq::Web => "/sidekiq"
  resources :servers, only: [:show, :index]
end
```

Controller and model example:

```ruby
# app/models/server.rb
class Server < ApplicationRecord
  validates :name, :region, presence: true
end

# app/controllers/servers_controller.rb
class ServersController < ApplicationController
  def index
    render json: Server.all.order(:id)
  end
  def show
    render json: Server.find(params[:id])
  end
end
```

Quick smoke test:

```bash
# create table, boot, hit endpoints
docker compose -f docker-compose.dev.yml run --rm web bin/rails db:create db:migrate
docker compose -f docker-compose.dev.yml exec web bin/rails runner "Server.create!(name: 'api', region: 'ap-southeast-2')"
curl http://localhost:3000/servers
```

---

## Exercises for muscle memory

- Wire a new queue named `burst` with higher priority for short-lived jobs. Prove it drains before `default`.
- Stress test Sidekiq by setting `SIDEKIQ_CONCURRENCY=2,10,50` and measure DB pool exhaustion. Tune `pool` in `database.yml` to match Puma + Sidekiq concurrency.
- Switch Redis to ElastiCache in a sandbox AWS account. Update `REDIS_URL` to `rediss://` and validate TLS.
- Add structured JSON logging and ship to CloudWatch. Confirm parsing with CloudWatch Logs Insights.
- Build two images from the same repo: a dev image with build tools, a prod image with multi-stage. Compare sizes.

---

## Opinionated defaults that keep you safe

- Ruby 3.4.x, Rails 7.2 or 8.0, Puma, Sidekiq, Redis 7.x
- Log to STDOUT everywhere
- Health check endpoint for ALB: `GET /up` returns 200
- Secrets from SSM or Secrets Manager, never in the image
- One image, two ECS services: `web` and `worker`, each with its own scaling policy
- Alarms on 5xx, queue depth, and Sidekiq retry count

---

## Sources and credibility

- Ruby official releases list showing Ruby 3.4.5 and 3.3.9 as current lines. **Credibility: High**. ([Ruby][1])
- Rails 7.2 release notes and defaults, including dev containers and Puma changes. **Credibility: High**. ([Ruby on Rails Guides][2], [GitHub][18])
- Rails 8.0 release notes. **Credibility: High**. ([Ruby on Rails Guides][19])
- Sidekiq docs on Redis usage and Active Job adapter. **Credibility: High**. ([GitHub][6])
- Active Job adapter reference. **Credibility: High**. ([Ruby on Rails API][4])
- Puma deployment guidance and concurrency notes. **Credibility: Medium High** (Heroku Dev Center is widely referenced). ([Heroku Dev Center][3])
- Multi-stage Docker patterns for Rails. **Credibility: Medium High** (industry best practice articles). ([Nick Janetakis][13], [whittakertech.com][15])
- Docker’s official Rails Compose sample. **Credibility: High**. ([Docker Documentation][14])
- ElastiCache best practices and client guidance for Redis. **Credibility: High**. ([AWS Documentation][9])
- App Runner runtime and 2025 updates. **Credibility: High** (AWS docs and roadmap). ([AWS Documentation][17])

---

[1]: https://www.ruby-lang.org/en/downloads/releases/ "Ruby Releases"
[2]: https://guides.rubyonrails.org/7_2_release_notes.html?utm_source=chatgpt.com "Ruby on Rails 7.2 Release Notes"
[3]: https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server?utm_source=chatgpt.com "Deploying Rails Applications with the Puma Web Server"
[4]: https://api.rubyonrails.org/classes/ActiveJob/QueueAdapters.html?utm_source=chatgpt.com "Active Job adapters - Ruby on Rails"
[5]: https://github.com/sidekiq/sidekiq/wiki/Active-Job?utm_source=chatgpt.com "Active Job · sidekiq/sidekiq Wiki · GitHub"
[6]: https://github.com/sidekiq/sidekiq/wiki/Using-Redis?utm_source=chatgpt.com "Using Redis · sidekiq/sidekiq Wiki · GitHub"
[7]: https://aws.amazon.com/blogs/database/best-practices-valkey-redis-oss-clients-and-amazon-elasticache/?utm_source=chatgpt.com "Best practices: Valkey/Redis OSS clients and Amazon ElastiCache"
[8]: https://api.rubyonrails.org/classes/ActiveJob/QueueAdapters/SidekiqAdapter.html?utm_source=chatgpt.com "Sidekiq adapter for Active Job - Ruby on Rails"
[9]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/BestPractices.html?utm_source=chatgpt.com "ElastiCache best practices and caching strategies - Amazon ElastiCache"
[10]: https://werf.io/guides/rails/200_real_apps/020_logging.html?utm_source=chatgpt.com "Logging | Real-world apps | Rails | werf"
[11]: https://www.bigbinary.com/blog/rails-5-allows-to-send-log-to-stdout-via-environment-variable?utm_source=chatgpt.com "Rails 5 Sending STDOUT via environment variable"
[12]: https://guides.rubyonrails.org/security.html?utm_source=chatgpt.com "Securing Rails Applications - Ruby on Rails Guides"
[13]: https://nickjanetakis.com/blog/shrink-your-docker-images-by-50-percent-with-multi-stage-builds?utm_source=chatgpt.com "Shrink Your Docker Images by ~50% with Multi-Stage Builds"
[14]: https://docs.docker.com/reference/samples/rails/?utm_source=chatgpt.com "Rails samples | Docker Docs"
[15]: https://whittakertech.com/blog/rails-docker-multi-stage-builds/?utm_source=chatgpt.com "Rails Docker Architecture: Multi-Stage Builds and Base Images"
[16]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-best-practices.html?utm_source=chatgpt.com "Amazon ECS best practices - Amazon Elastic Container Service"
[17]: https://docs.aws.amazon.com/apprunner/latest/relnotes/relnotes-2025.html?utm_source=chatgpt.com "App Runner release notes for 2025 - AWS App Runner"
[18]: https://github.com/rails/rails/blob/main/guides/source/7_2_release_notes.md?utm_source=chatgpt.com "rails/guides/source/7_2_release_notes.md at main - GitHub"
[19]: https://guides.rubyonrails.org/8_0_release_notes.html?utm_source=chatgpt.com "Ruby on Rails 8.0 Release Notes"
