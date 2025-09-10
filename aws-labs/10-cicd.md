# Lab 07: CI/CD for ECS

## Objectives

- Build and deploy automatically on commit using CodeBuild/CodePipeline (or an alternative).

## Tasks

1. Create a CodeStar Connections connection to GitHub (one-time, requires console handshake).
2. CodeBuild project with IAM role: docker build, login to ECR, push; output image URI.
3. CodePipeline: Source (GitHub via Connection) → Build → Deploy (update task definition image, force deployment).
4. Manual approval stage optional for staging.

## Acceptance Criteria

- Commit triggers build; pipeline pushes image and updates ECS task definition.
- Service rolls to new tasks; ALB remains healthy.

## Hints

- GitHub via CodeStar Connections:
  - Terraform: `aws_codestarconnections_connection` for the logical connection object.
  - After `apply`, complete the “Connect” handshake in the AWS Console to authorize the GitHub App and select repositories. For a user account, you must explicitly authorize the repo; for orgs, ensure the app is installed and allowed access to the repo.
- Source action in CodePipeline uses the Connection ARN and `FullRepositoryId` like `loftwah/devops-refresher`.
  - For this lab, use `FullRepositoryId = loftwah/demo-node-app` (single repo for ECS and EKS).
- Alternative: Use GitHub Actions + OIDC into AWS; skip CodePipeline and call Terraform/ECR/ECS via Actions.
- Keep buildspec in the app repo; pin tool versions for reproducibility.

### Slack Notifications (Build/Pipeline)

- Use EventBridge rules on CodeBuild and CodePipeline state changes to invoke your Slack notifier Lambda (see `slack-cicd-integration.md`).
- Typical events:
  - CodePipeline: `Execution State Change` and `Stage State Change`
  - CodeBuild: `Build State Change`
- Payload includes pipeline/build name, commit ID, and status; map these to Slack channels and formatting as per the notifier doc.

## Repo Naming Pattern (Demo Apps)

- `loftwah/demo-node-app`, `loftwah/demo-rails-app`, `loftwah/demo-go-service`.
- The app repo contains a Dockerfile, health endpoint, and minimal app code.
- Pipelines build/push to ECR, then deploy to ECS; the same image/tag is used by EKS.
