# Terraform Import Examples and Playbook

This runbook shows practical, copy/paste workflows for adopting resources that were created outside of Terraform (Console ClickOps, other stacks) into the correct module/state, and for moving resources between modules without recreating them.

## When to Use What

- `terraform import <addr> <id>`: Bring an existing resource under Terraform control in the current state.
- `terraform state mv <src> <dst>`: Move a resource between addresses/modules in the same state (no API calls).
- `terraform state pull`/`push`: Advanced — migrate resources across states if needed.

Tip: Always write the resource block first (minimal, matching reality), then import, then `plan` to reconcile.

---

## Scenario A: Adopt CI/CD IAM Roles into Lab 06 (from Lab 15 or Console)

Context: Roles `devops-refresher-codebuild-role` and `devops-refresher-codepipeline-role` already exist. Lab 06 now owns CI/CD IAM.

1. In `aws-labs/06-iam`, ensure role resources exist in code (they do).

2. Import existing roles + inline policies:

```
cd aws-labs/06-iam
terraform init
terraform import aws_iam_role.codebuild devops-refresher-codebuild-role
terraform import aws_iam_role_policy.codebuild_inline devops-refresher-codebuild-role:devops-refresher-codebuild
terraform import aws_iam_role.codepipeline devops-refresher-codepipeline-role
terraform import aws_iam_role_policy.codepipeline_inline devops-refresher-codepipeline-role:devops-refresher-codepipeline
terraform validate && terraform plan
```

3. Resolve drift if `plan` shows differences (e.g., tags, policies). Update HCL until `plan` is empty, then `apply`.

IDs cheat sheet:

- `aws_iam_role`: role name
- `aws_iam_role_policy`: `<role-name>:<inline-policy-name>`

---

## Scenario B: Import an S3 Artifacts Bucket (created via Console) into Lab 15

1. Add/confirm bucket resource in `aws-labs/15-cicd-ecs-pipeline/main.tf`:

```
resource "aws_s3_bucket" "artifacts" {
  bucket = var.artifacts_bucket_name
}
```

2. Import the existing bucket by name:

```
cd aws-labs/15-cicd-ecs-pipeline
terraform import aws_s3_bucket.artifacts <bucket-name>
terraform import aws_s3_bucket_versioning.artifacts <bucket-name>
terraform plan
```

3. If `plan` shows differences (e.g., versioning not enabled), either enable it in Console or in Terraform and `apply`.

IDs cheat sheet:

- `aws_s3_bucket`: bucket name
- `aws_s3_bucket_versioning`: bucket name

Gotchas:

- Bucket names are global. If you changed names, update IAM policies referencing the bucket ARN.

---

## Scenario C: Move a Resource Between Modules (No Recreate)

Context: A role defined in module A should live in module B.

1. Ensure the destination module has an identical resource block (same attributes).

2. Move it in state:

```
terraform state mv 'module.a.aws_iam_role.example' 'module.b.aws_iam_role.example'
```

3. Run `terraform plan` to confirm no changes.

Notes:

- If source and destination are different states, export/import with `terraform state pull`/`push` or use `import` in the destination.

---

## Scenario D: Import a CodePipeline Built via Console

Prereqs in code:

- Artifact S3 bucket resource or `var.artifacts_bucket_name` referencing an existing bucket.
- IAM roles (CodePipeline/CodeBuild) already owned by Lab 06.
- CodeBuild project resource defined (or use data source).

Steps:

```
cd aws-labs/15-cicd-ecs-pipeline
# Import the pipeline by name
terraform import aws_codepipeline.app devops-refresher-app-pipeline
terraform plan
```

Common drift to fix:

- `artifact_store` bucket name mismatch → point to the correct bucket.
- IAM role ARN mismatch → set `role_arn` from Lab 06 outputs.
- Stages config differs → align HCL with what exists or recreate intentionally.

IDs cheat sheet:

- `aws_codepipeline`: pipeline name
- `aws_codebuild_project`: project name

---

## General Checklist Before Import

- Region/profile: `provider "aws" { region = ..., profile = ... }` matches where the resource lives.
- Minimal HCL first: define the resource with only what’s known to exist, avoiding computed/defaulted attributes that might introduce drift.
- Dependencies: make sure referenced ARNs/buckets/roles exist in code and state.
- After import → `terraform plan`: prefer updating HCL to match reality unless you intend to change the resource.

## How You Know You Need Import vs Move

- Error `EntityAlreadyExists` on create: the resource already exists → import it.
- You want to change which module manages a resource, not recreate → `terraform state mv`.
- Data sources are for reading only; if you want Terraform to manage lifecycle, use a resource + import/move.

## Quick Reference: Import IDs

- IAM Role: role name (e.g., `devops-refresher-codepipeline-role`)
- IAM Inline Policy: `<role-name>:<policy-name>`
- S3 Bucket/Versioning: bucket name
- CodePipeline: pipeline name
- CodeBuild Project: project name
- ECR Repo: repository name

## See Also

- `aws-labs/06-iam/README.md` → Migration note and Permissions checklist
- `aws-labs/15-cicd-ecs-pipeline/README.md` → Ownership & Order, Common Failures and Fixes
