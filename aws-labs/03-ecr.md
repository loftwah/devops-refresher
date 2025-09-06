# Lab 03: ECR and Image Build

## Objectives

- Create an ECR repository and push a sample image.

## Tasks

1. Create `aws_ecr_repository` with image scanning on push enabled.
2. Docker login to ECR; build a sample Nginx image; tag and push `:staging`.
3. Optional: Add lifecycle policy to retain last 10 images.

## Acceptance Criteria

- `aws ecr describe-images` shows your `:staging` tag.

## Hints

- Use `aws ecr get-login-password` with your profile to login.
- Consider immutable tags and digest pinning for production.
