# CloudTrail Notes (Management vs Data Events)

- Management events: control plane operations (IAM, EC2 start/stop, KMS key changes). Enabled by default on trails.
- Data events: S3 object‑level, Lambda invoke, DynamoDB item‑level — high volume, disabled by default; enable selectively.
- Example: Debug AccessDenied on KMS decrypt — check CloudTrail for `kms:Decrypt` denials and which principal/role attempted it; correlate with the KMS key policy and IAM policy.

Teardown: delete trail and S3 bucket (after emptying) if created; this refresher does not include a dedicated CloudTrail lab.
