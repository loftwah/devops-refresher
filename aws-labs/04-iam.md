# Lab 04: IAM for ECS

## Objectives

- Create task execution and task roles with least privilege.

## Tasks

1. Task execution role: Allow ECR GetAuthorizationToken, ECR pull, CloudWatch Logs create/put.
2. Task role: Minimal runtime permissions (e.g., read specific SSM parameters).
3. Output ARNs for use in task definitions.

## Acceptance Criteria

- ECS can pull images and write logs without permission errors.

## Hints

- Use AWS managed policy `service-role/AmazonECSTaskExecutionRolePolicy` as a baseline, then tailor.
- Scope SSM access by parameter path and environment tags.
