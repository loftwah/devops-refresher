# Lab 08 – S3 (App Bucket)

## What Terraform Actually Creates (main.tf)

- Random suffix via `random_id.suffix` to ensure unique bucket names when not explicitly set.
- `aws_s3_bucket.this` with name `coalesce(var.bucket_name, "${var.bucket_prefix}-${random_id.suffix.hex}")`.
- `aws_s3_bucket_public_access_block` blocking all public ACLs/policies.
- `aws_s3_bucket_versioning` enabled.
- `aws_s3_bucket_server_side_encryption_configuration` with SSE-S3 (`AES256`).
- Outputs: `bucket_name`, `bucket_arn`.

There is no bucket policy in this lab because access is granted via IAM on the task role in Lab 06 to a prefix scope: `s3://<bucket>/app/*`.

## Variables (variables.tf)

- `bucket_name` (string|null): explicit name; if null, a name is generated.
- `bucket_prefix` (string): prefix used when generating the name. Default `devops-refresher-staging-app`.

## Apply

```bash
cd aws-labs/08-s3
terraform init
terraform apply -auto-approve

# Optional explicit name
# terraform apply -auto-approve -var bucket_name=my-explicit-bucket-name
```

## How Other Labs Use This

- IAM (Lab 06): auto‑detects this bucket via remote state and grants least‑priv runtime access to `app/*` objects.
- Parameter Store (Lab 11): reads `bucket_name` and writes `S3_BUCKET` for consumers.
- App endpoints: `/s3/:id` map to `s3://$S3_BUCKET/app/<id>.txt`.

## Outputs

- `bucket_name` — wire into Parameter Store `S3_BUCKET`.
- `bucket_arn` — for reference.

## Cleanup

Empty the bucket first, then:

```bash
terraform destroy -auto-approve
```
