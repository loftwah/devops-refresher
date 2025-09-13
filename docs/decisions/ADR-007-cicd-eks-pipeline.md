# ADR-007: CI/CD for EKS — Separate Pipeline with Inline Helm, Same Repo Trigger

## Status

Accepted (Staging lab context)

## Decision

Add a separate CodePipeline (Lab 21) that deploys the in-repo Helm chart to EKS using an inline buildspec in CodeBuild. Source is the same GitHub repo/branch as the ECS pipeline (Lab 15). The EKS pipeline waits for the ECR image tag `<git-sha>` to exist before running `helm upgrade --install`.

## Context

- We already have Lab 15 (CI/CD to ECS) earlier in the sequence. Renumbering or modifying it would break ordering and cross-references.
- We want a “build once, deploy to ECS and EKS” model and keep all deploy logic visible in this repo, similar to the inline buildspec approach used previously.
- CodePipeline supports multiple pipelines on the same repo/branch via CodeConnections.

## Alternatives Considered

1. Single pipeline with two deploy stages (ECS + EKS):
   - Pros: one artifact and source of truth; airtight consistency.
   - Cons: requires editing Lab 15 and reordering, which conflicts with the current lab numbering and dependencies.

2. Separate EKS pipeline (chosen):
   - Pros: preserves lab order and content; minimal coupling to the ECS pipeline; easy to reason about.
   - Cons: two pipelines trigger on the same push; EKS pipeline must wait for the ECR tag (handled via a simple poll loop).

## Consequences

- Employs inline buildspec for Helm deploy to keep the EKS CD logic centralized in this repo.
- Both pipelines run on every push to `main` (expected in staging). The EKS deploy blocks until the image tag appears.
- Future improvement: Fold EKS deploy into a single multi-target pipeline when the lab schedule changes or when we intentionally rev the lab numbering.
