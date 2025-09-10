# Docker Build Secrets: Practical Examples

This page shows end-to-end examples of using Docker BuildKit secrets for common ecosystems in this repo: npm, Yarn, Vite, Rails/Webpacker, and Ruby Bundler. All examples avoid `ARG` for secrets and use `RUN --mount=type=secret` so nothing lands in image layers.

Pre-reqs

- Use the modern Dockerfile syntax header: `# syntax=docker/dockerfile:1.7`
- Build with Buildx: `docker buildx build ...`

Notes

- Replace the registry/token examples with your org’s settings.
- For private Git deps, see the SSH example at the end.

## npm (private registry token)

Dockerfile

```dockerfile
# syntax=docker/dockerfile:1.7
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
# Mount token as a secret; do not persist .npmrc in layers
RUN --mount=type=secret,id=npm_token sh -lc \
    'echo "//registry.npmjs.org/:_authToken=$(cat /run/secrets/npm_token)" > .npmrc && npm ci && rm -f .npmrc'

COPY . .
# Example: Vite or any build step; safe to run without secrets
RUN npm run build

FROM node:20-alpine AS runtime
WORKDIR /app
COPY --from=build /app/dist ./dist
COPY --from=build /app/package.json ./
RUN npm pkg set scripts.start="node dist/server.js" && npm i --omit=dev
EXPOSE 3000
CMD ["npm","start"]
```

Build command

```
docker buildx build \
  --secret id=npm_token,env=NPM_TOKEN \
  -t myorg/demo-npm:staging .
```

## Yarn (reads .npmrc)

Yarn can consume a temporary `.npmrc` like npm does.

Dockerfile

```dockerfile
# syntax=docker/dockerfile:1.7
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json yarn.lock ./
RUN --mount=type=secret,id=npm_token sh -lc \
    'echo "//registry.npmjs.org/:_authToken=$(cat /run/secrets/npm_token)" > .npmrc && yarn install --frozen-lockfile && rm -f .npmrc'
COPY . .
RUN yarn build
```

Build command

```
docker buildx build --secret id=npm_token,env=NPM_TOKEN -t myorg/demo-yarn:staging .
```

## Vite (frontend build)

Combine with npm or Yarn examples above. If you need private registries during the build, use the secret mount for the install step only.

Dockerfile

```dockerfile
# syntax=docker/dockerfile:1.7
FROM node:20-alpine AS build
WORKDIR /web
COPY package.json package-lock.json vite.config.* ./
RUN --mount=type=secret,id=npm_token,required=false sh -lc \
    'if [ -f /run/secrets/npm_token ]; then echo "//registry.npmjs.org/:_authToken=$(cat /run/secrets/npm_token)" > .npmrc; fi; \
     npm ci; rm -f .npmrc || true'
COPY . .
RUN npm run build

FROM nginx:1.27-alpine
COPY --from=build /web/dist /usr/share/nginx/html
```

Build command

```
docker buildx build --secret id=npm_token,env=NPM_TOKEN -t myorg/vite-static:staging .
```

## Rails + Webpacker

Rails apps using Webpacker typically need Bundler (gems) and Yarn/npm for packs. Use BuildKit secrets for Bundler config and for npm auth, if needed.

Dockerfile

```dockerfile
# syntax=docker/dockerfile:1.7
ARG RUBY_VERSION=3.2
FROM ruby:${RUBY_VERSION}-slim AS base
ENV RAILS_ENV=production RACK_ENV=production BUNDLE_DEPLOYMENT=1 BUNDLE_PATH=/bundle
RUN apt-get update && apt-get install -y --no-install-recommends build-essential git curl nodejs yarn libpq5 \
  && rm -rf /var/lib/apt/lists/*

FROM base AS builder
WORKDIR /app
COPY Gemfile Gemfile.lock ./
# Mount private Bundler config; not persisted
RUN --mount=type=secret,id=bundle_config,target=/root/.bundle/config bundle install --jobs 4 --retry 3

# JS deps (Webpacker). Mount npm token only for install if needed
COPY package.json yarn.lock ./
RUN --mount=type=secret,id=npm_token,required=false sh -lc \
    'if [ -f /run/secrets/npm_token ]; then echo "//registry.npmjs.org/:_authToken=$(cat /run/secrets/npm_token)" > .npmrc; fi; \
     yarn install --frozen-lockfile; rm -f .npmrc || true'

COPY . .
# SECRET_KEY_BASE is required for assets:precompile in many setups; use a throwaway
RUN SECRET_KEY_BASE=dummy bundle exec rake assets:precompile

FROM base AS runtime
WORKDIR /app
RUN useradd -r -u 10001 -g users appuser
COPY --from=builder /bundle /bundle
COPY --from=builder /app /app
ENV RAILS_SERVE_STATIC_FILES=1 RAILS_LOG_TO_STDOUT=1
USER appuser
EXPOSE 3000
CMD ["bash","-lc","bundle exec puma -C config/puma.rb"]
```

Build command

```
docker buildx build \
  --secret id=bundle_config,src=$HOME/.bundle/config \
  --secret id=npm_token,env=NPM_TOKEN \
  -t myorg/rails-webpacker:staging .
```

## Ruby Bundler (gems only)

Dockerfile

```dockerfile
# syntax=docker/dockerfile:1.7
FROM ruby:3.2-slim AS builder
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN --mount=type=secret,id=bundle_config,target=/root/.bundle/config bundle install --jobs 4 --retry 3
```

Build command

```
docker buildx build --secret id=bundle_config,src=$HOME/.bundle/config -t myorg/bundler-only:test .
```

## Private Git Dependencies via SSH

If your npm/Yarn/Bundler configs reference private Git repositories, forward an SSH agent instead of copying keys.

Dockerfile

```dockerfile
# syntax=docker/dockerfile:1.7
FROM alpine/git AS src
RUN --mount=type=ssh git clone git@github.com:org/private-repo.git /tmp/repo
```

Build command

```
docker buildx build --ssh default -t myorg/uses-ssh:latest .
```

## GitHub Actions (Buildx + Secrets)

Use `docker/build-push-action` with the `secrets` input to pass BuildKit secrets.

```yaml
name: build-push
on: { push: { branches: [main] } }
permissions: { id-token: write, contents: read }
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-qemu-action@v3
        with: { platforms: arm64, amd64 }
      - uses: docker/setup-buildx-action@v3
      - uses: aws-actions/configure-aws-credentials@v4
        with: { aws-region: ap-southeast-2 }
      - uses: aws-actions/amazon-ecr-login@v2
      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: 139294524816.dkr.ecr.ap-southeast-2.amazonaws.com/demo-node-app:staging
          platforms: linux/amd64,linux/arm64
          secrets: |
            npm_token=${{ secrets.NPM_TOKEN }}
            bundle_config=${{ secrets.BUNDLE_CONFIG }}
          build-args: |
            COMMIT_SHA=${{ github.sha }}
```

Notes

- `secrets.NPM_TOKEN` and `secrets.BUNDLE_CONFIG` should be configured in your repo settings. `BUNDLE_CONFIG` is the textual content of the config; the action writes it to a temp file for BuildKit.
- Use the appropriate Dockerfile snippet above for npm/Yarn/Bundler.

## Multi-arch Builds Locally

To produce both ARM64 and x86_64 images under a single tag using Buildx:

```
REPO=139294524816.dkr.ecr.ap-southeast-2.amazonaws.com/demo-node-app
docker buildx build --platform linux/amd64,linux/arm64 -t $REPO:staging --push .
docker buildx imagetools inspect $REPO:staging
```

Tips

- Prefer native builders (Apple Silicon for arm64, Linux/Intel for amd64) for speed; QEMU emulation works but is slower.
- Ensure your base images/packages have variants for both architectures (Node, Ruby, system libs).
