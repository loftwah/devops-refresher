# ADR-005: CI/CD IAM Ownership and Consumption

Status: Accepted

Context

- The CI/CD pipeline (CodePipeline + CodeBuild) requires IAM roles. Initially, the pipeline lab created its own roles, which led to duplication and ownership ambiguity once we introduced a dedicated IAM lab.
- This caused two classes of issues:
  1. Missing permissions (e.g., `codestar-connections:UseConnection`) because the pipeline lab had “just-enough IAM”.
  2. Conflicts (`EntityAlreadyExists`) when moving IAM under the IAM lab while roles already existed.

Decision

- Lab 06 (IAM) owns all CI/CD IAM: CodeBuild and CodePipeline roles and inline policies.
- Lab 15 (pipeline) consumes the role ARNs via Terraform remote state outputs from Lab 06 and does not create IAM.
- S3 artifacts bucket access is granted in Lab 15 via a bucket policy targeting the pipeline role ARN to avoid tight coupling.

Consequences

- Apply order: Run Lab 06 before Lab 15.
- Migration path: If roles already exist (created earlier by Lab 15 or manually), import them into Lab 06 state with `terraform import` and then apply.
- Permissions checklist is documented in Lab 06 README to avoid future misses (notably `codestar-connections:UseConnection`).

How We’ll Know

- If Source stage errors with “Unable to use Connection” → CodePipeline role missing `UseConnection`.
- If Lab 06 fails with `EntityAlreadyExists` → import existing roles before applying.
- If Lab 15 fails with “Unsupported attribute” for IAM outputs → apply Lab 06 first (or import), then re-apply Lab 15.
