# ADR-008: Immutable Container Image Tags (No `latest`)

## Status

Accepted

## Decision

We tag every container image with an immutable identifier (Git commit SHA or promoted artifact tag) and deploy only those pinned tags. We never push or deploy the `latest` tag in automated pipelines.

## Context

- `latest` is only a naming convention in registries. It floats with every push, so orchestration platforms (ECS, EKS, Lambda) may pull a different image than the one that passed tests.
- Rollbacks become non-deterministic: re-deploying `latest` fetches the newest image, not the version we expect.
- Caches (AWS Fargate/EKS nodes, Docker, registries) rely on digest immutability. Reusing `latest` invalidates layers inconsistently and can mask drift in higher environments.
- AWS tooling supports immutable tags out of the box: CodeBuild exposes `CODEBUILD_RESOLVED_SOURCE_VERSION`, CodePipeline surfaces the commit SHA, and our existing `push-ecr.sh` already defaults to `git rev-parse --short HEAD` when no tag is supplied.

## Alternatives Considered

1. Continue pushing `latest` alongside immutable tags (previous behaviour):
   - Pros: familiar CLI usage; easy to `docker run repo/app:latest` locally.
   - Cons: pipelines and Terraform modules accidentally depend on `latest`; humans forget to update the pinned tag and drift creeps back in; rollbacks remain risky.

2. Timestamp-based tags (`20250302-123045`):
   - Pros: sortable; unique per build.
   - Cons: timestamps do not tie back to source code or Git history without additional metadata; harder to diff against commits.

3. Digest-only deployments (no tags):
   - Pros: strongest immutability guarantee; Kubernetes/ECS support digests.
   - Cons: ergonomically poor for humans; Terraform/Helm templates get noisy; CodePipeline stages still need a friendly tag for artifact promotion.

## Consequences

- CI stages must pass a tag (commit SHA or promoted alias) into `push-ecr.sh`/`docker buildx build`. The script keeps the SHA default to cover local builds.
- Terraform modules and Helm charts should reference the immutable tag variable (already provided in the labs) and remove any `:latest` fallbacks.
- We document local workflow: developers can `docker tag repo/app:<sha> repo/app:dev-local` if they need a floating alias on their machine, but they never push it upstream.
- Existing environments should be audited to ensure services reference immutable tags. Where `latest` is still in use, plan a redeploy with a pinned tag.
- This ADR supersedes ad-hoc guidance; `docs/aws-terraform-patterns.md` and related runbooks now link back here for rationale.

## When `latest` Is Acceptable (And When It Is Not)

Safe enough:

- **Local developer loops** where the image never leaves your laptop. `latest` as a temporary alias is fine so long as it is not pushed to a shared registry.
- **Third-party images you do not own** (for example `redis:latest` in a quickstart). Treat it like a convenience pointer; prefer pinning a digest or version for production, but grabbing `latest` interactively is an acceptable shortcut while exploring.
- **Ephemeral throwaway environments** (demo sandboxes, one-off workshops) provided you understand that every restart may pull a different upstream image.

Still avoid:

- **CI/CD pipelines, Terraform, Helm, or ECS/Kubernetes manifests** for first-party services. Use commit SHAs, semver, or digests so deployments are reproducible.
- **Promoted environments** (staging, prod, long-lived test). Rollbacks and drift detection break when tags float.
- **Security-conscious contexts** where you need a scan trail. Immutable tags (and ideally digests) are the only way to prove which code is running.

Rule of thumb: `latest` is a human convenience but not an automation contract. If the image ends up in ECR or is referenced by infrastructure code, give it an immutable name first. For upstream open-source images you consume, periodically convert `latest` to a pinned version/digest once you have validated it.
