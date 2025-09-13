# ADR-006: Artifacts Bucket Access — Bucket Policy in Pipeline Lab vs IAM Lab

Status: Accepted

Context

- The CI/CD pipeline (CodePipeline → CodeBuild → ECS) uses an S3 artifacts bucket. Both the CodePipeline role and the CodeBuild role must access artifacts in this bucket.
- CI/CD IAM roles are defined in `aws-labs/06-iam` and consumed by `aws-labs/15-cicd-ecs-pipeline` via remote state.
- Bucket names may be randomized (to avoid global name clashes) and the pipeline lab may create or reuse a bucket.
- We recently hit an AccessDenied in CodeBuild during DOWNLOAD_SOURCE because the bucket policy allowed only the CodePipeline role, not the CodeBuild role.

Decision

- Keep the artifacts S3 bucket policy with the bucket in the pipeline lab (`aws-labs/15-cicd-ecs-pipeline`).
- Grant BOTH principals access via the bucket policy:
  - CodePipeline role: `s3:GetObject`, `s3:GetObjectVersion`, `s3:PutObject`, and `s3:GetBucketVersioning`.
  - CodeBuild role: `s3:GetObject`, `s3:GetObjectVersion`, `s3:PutObject`, and `s3:GetBucketVersioning`.
- Do not hardcode bucket-specific S3 access in the IAM lab’s identity policies.

Rationale

- Resource owns policy: Resource-based policies belong with the resource owner. The pipeline lab creates/owns the S3 bucket, so it owns who can access it.
- Avoid tight coupling and cycles: Encoding bucket ARNs in IAM lab would couple Lab 06 to Lab 15 naming and state, and risks circular dependencies across Terraform states.
- Flexibility for multiple pipelines/buckets: The pipeline lab can scope access per bucket and per principal without bloating global IAM.
- Clearer blast radius: Changing bucket access does not require reapplying global IAM; changes are localized to the pipeline/bucket module.
- Cross-account readiness: Resource policies are the standard way to grant cross-account access if needed later.

Consequences

- Apply order: Apply IAM lab (roles) first, then pipeline lab (bucket + policy).
- Reuse path: If `create_artifacts_bucket = false`, the existing bucket must have an equivalent policy attached. Either bring it under Terraform in the pipeline lab or update manually to match this ADR.
- Troubleshooting: If CodeBuild fails on DOWNLOAD_SOURCE with `s3:GetObject AccessDenied`, verify the bucket policy includes the CodeBuild role principal and the relevant actions.

Alternatives Considered

- Identity-based S3 permissions in IAM lab referencing the bucket ARN(s):
  - Pros: Centered IAM changes; fewer resource policies.
  - Cons: Tight coupling to bucket names/regions; harder to manage multiple buckets; still often need a bucket policy for cross-account cases.

References

- Bucket policy implementation: `aws-labs/15-cicd-ecs-pipeline/main.tf:125`
- CI/CD roles definition: `aws-labs/06-iam/main.tf:166` (CodeBuild), `aws-labs/06-iam/main.tf:215` (CodePipeline)

