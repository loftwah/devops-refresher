# CI/CD → ECS Deploy permissions runbook

## TL;DR

- Validate first: `aws-labs/scripts/validate-cicd.sh`
- If blocked, break-glass to ship: apply Lab 06 (IAM) with broad ECS + PassRole (already implemented).
- After ship, tighten back to least-privilege and re-run validator.

## What ECS Deploy needs (minimal)

- CodePipeline role:
  - ECS: `ecs:ListClusters`, `ecs:DescribeClusters`, `ecs:ListServices`, `ecs:DescribeServices`, `ecs:DescribeTaskDefinition`, `ecs:ListTaskDefinitions`, `ecs:DescribeTasks`, `ecs:DescribeTaskSets`, `ecs:RegisterTaskDefinition`, `ecs:UpdateService` on `*`.
  - PassRole: `iam:PassRole` to the ECS task execution role and task role with `iam:PassedToService` equal to `ecs-tasks.amazonaws.com` (and include `ecs.amazonaws.com` for provider nuance).
- S3 artifacts access is granted by the artifacts bucket policy (resource-based) to the CodePipeline and CodeBuild roles: `s3:GetObject`, `s3:GetObjectVersion`, `s3:PutObject` on bucket/prefix, and `s3:GetBucketVersioning` on the bucket.

## Where this lives in Terraform

- CodePipeline role + inline policy: `aws-labs/06-iam/main.tf` (search for `codepipeline_inline`).
- CodeBuild role + inline policy: `aws-labs/06-iam/main.tf` (search for `codebuild_inline`).
- Artifacts bucket policy granting S3 access to both roles: `aws-labs/15-cicd-ecs-pipeline/main.tf` (search for `aws_s3_bucket_policy.artifacts_access`).
- Pipeline wiring and ECS Deploy action: `aws-labs/15-cicd-ecs-pipeline/main.tf`.

## Diagnose quickly

1. One-shot validator (recommended):

```bash
aws-labs/scripts/validate-cicd.sh
```

- Confirms:
  - Artifacts bucket policy grants required S3 actions to both principals.
  - Pipeline uses the expected role.
  - ECS cluster/service exist in ap-southeast-2.
  - Simulates IAM for ECS actions and PassRole on the live task roles with both principals.

2. If a pipeline execution failed, pull the exact message and artifacts:

```bash
PIPELINE=devops-refresher-app-pipeline
EXEC_ID=<paste>
aws codepipeline get-pipeline-execution \
  --profile devops-sandbox --region ap-southeast-2 \
  --pipeline-name "$PIPELINE" --pipeline-execution-id "$EXEC_ID" | jq .
aws codepipeline list-action-executions \
  --profile devops-sandbox --region ap-southeast-2 \
  --pipeline-name "$PIPELINE" --filter pipelineExecutionId="$EXEC_ID" | jq .
```

3. Verify S3 policy (resource-based) used by the run:

```bash
BUCKET=<from list-action-executions>
aws s3api get-bucket-policy \
  --profile devops-sandbox --region ap-southeast-2 \
  --bucket "$BUCKET" --query Policy | jq -r .
```

Note: IAM simulation won’t reflect S3 resource-based allows; rely on bucket policy + successful run.

## Break-glass to ship

- Purpose: unblock Deploy immediately when permissions are flaky or unknown.
- Current setting (Lab 06):
  - Adds `ecs:*` on `*` and unconditional `iam:PassRole` for the CodePipeline role.
- Apply:

```bash
terraform -chdir=aws-labs/06-iam apply -auto-approve
```

- Verify and run:

```bash
aws-labs/scripts/validate-cicd.sh
aws-labs/scripts/verify-pipeline.sh devops-refresher-app-pipeline
```

## Tighten back to least privilege (when ready)

- Remove the break-glass statements from `aws-labs/06-iam/main.tf` and keep the minimal ECS actions + PassRole with both principals.
- Apply and validate.

## Why we went break-glass

- We hit an ECS Deploy "provided role does not have sufficient permissions" error despite minimal actions being present; root cause is PassRole evaluation nuances and AWS returning URL-encoded inline policies that our old validator misread.
- We updated the validator to simulate permissions against the live task roles with both principals, but we retained a break-glass path to avoid blocking releases.

## Region and state

- Infra runs in ap-southeast-2. Remote Terraform state is in us-east-1 by design; that’s fine.

## Quick checklist before a release

- [ ] `aws-labs/scripts/validate-cicd.sh` is green
- [ ] CodePipeline role and artifacts bucket policy look correct
- [ ] ECS service exists and is ACTIVE
- [ ] If blocked, use break-glass; then tighten later
