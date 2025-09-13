# ADR-004: Buildspec Location (Inline vs App Repo)

Status: Accepted

Context

- Our CI/CD pipeline uses AWS CodePipeline + CodeBuild to build and deploy `loftwah/demo-node-app` to ECS.
- The build process needs a `buildspec.yml`. We can place it in the app repo or inject it inline in the CodeBuild project via Terraform.

Options Considered

- App repo buildspec (conventional):
  - Pros: Single source, build changes version with app; easier for app devs to iterate.
  - Cons: Duplicated patterns across many repos; central standards are harder to enforce.
- Inline buildspec in infra (Terraform):
  - Pros: Centralized control and standardization; build policy reviewable in infra PRs; no dependency on app repo for CI shape.
  - Cons: Coordination required when build changes must accompany app code changes; pipeline has two moving parts (app code + infra policy).

Decision

- Use an inline buildspec for this lab (`use_inline_buildspec = true` in `aws-labs/15-cicd-ecs-pipeline`).
- Expose `inline_buildspec_override` to allow tailored YAML without editing Terraform logic.
- Provide an easy switch to app‑repo buildspec by setting `use_inline_buildspec = false` (expecting `buildspec.yml` at repo root).

Consequences

- The pipeline is self‑contained in this repo; onboarding is simpler for labs.
- Teams can still migrate the buildspec to the app repo later for autonomy, without changing pipeline stages.
- We document variable/secrets handling in `aws-labs/15-cicd-ecs-pipeline/README.md` and `docs/build-vs-runtime-config.md`.
