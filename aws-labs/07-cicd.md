# Lab 07: CI/CD for ECS

## Objectives

- Build and deploy automatically on commit using CodeBuild/CodePipeline (or an alternative).

## Tasks

1. CodeBuild project with IAM role: docker build, login to ECR, push; output image URI.
2. CodePipeline: Source → Build → Deploy (update task definition image, force deployment).
3. Manual approval stage optional for staging.

## Acceptance Criteria

- Commit triggers build; pipeline pushes image and updates ECS task definition.
- Service rolls to new tasks; ALB remains healthy.

## Hints

- For GitHub, use connection via CodeStar or set up OIDC with GitHub Actions instead.
- Keep buildspec in repo; pin versions for reproducibility.
