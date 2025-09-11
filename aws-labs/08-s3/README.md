# Lab 08 – S3 (App Bucket)

## Objectives

- Create a private S3 bucket for the app’s object CRUD.

## Prerequisites

- None beyond AWS account and backend.

## Apply

```bash
cd aws-labs/08-s3
terraform init
terraform apply -auto-approve

# Optionally, override the generated name
# terraform apply -var bucket_name=my-explicit-bucket-name -auto-approve
```

## Outputs

- `bucket_name` – wire into Parameter Store `S3_BUCKET`.

## Consumption

- ECS task role needs least-priv S3 access to this bucket/prefix.
- App’s `/s3/:id` endpoints target `s3://$S3_BUCKET/app/<id>.txt`.

## Cleanup

Empty the bucket first, then:

```bash
terraform destroy -auto-approve
```
