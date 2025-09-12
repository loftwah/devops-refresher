# Lab 06 – IAM (ECS Roles)

## Objectives

- Create two roles:
  - ECS Task Execution Role: pull ECR, write logs, read Secrets/SSM (for ECS `secrets`), optional KMS decrypt.
  - ECS Task Role: least-privilege S3 access (bucket/prefix), optional SSM read at runtime.

## Apply

```bash
cd aws-labs/06-iam
terraform init
terraform apply \
  -var s3_bucket_name=$(cd ../08-s3 && terraform output -raw bucket_name 2>/dev/null || echo "") \
  -var grant_task_role_ssm_read=false \
  -var ssm_path_prefix=/devops-refresher/staging/app \
  -auto-approve
```

## Outputs

- `execution_role_arn` – pass to ECS Service.
- `task_role_arn` – pass to ECS Service.

## Notes

- Execution role has `AmazonECSTaskExecutionRolePolicy` and optional read to Secrets Manager/SSM under `/devops-refresher/staging/app`.
- Secrets Manager policy uses prefix with a slash: `...:secret:/devops-refresher/staging/app/*`.
  - Important: using `-*` (dash then wildcard) would not match nested names like `/devops-refresher/staging/app/DB_PASS-xxxxx` and will cause `AccessDeniedException` on `secretsmanager:GetSecretValue`.
- Task role can read/write `s3://$bucket/app/*` and list the bucket; enable SSM read if your app fetches SSM at runtime.

### ECS Exec requirements

- To use ECS Exec, tasks must establish SSM channels. We attach the AWS managed policy `AmazonSSMManagedInstanceCore` to both the task role and the execution role in Terraform (see `main.tf`). This grants the necessary `ssmmessages`, `ec2messages`, and `ssm` permissions.
- Ensure your VPC has the three interface endpoints: `ssm`, `ssmmessages`, and `ec2messages` (present in this lab’s VPC validation). If using private subnets with NAT, NAT is sufficient; interface endpoints also work.
- After applying IAM changes, force a new deployment of the ECS service so new tasks start with the updated role attachments.

```bash
aws --profile devops-sandbox --region ap-southeast-2 ecs update-service \
  --cluster devops-refresher-staging --service app --force-new-deployment
```

### Verify with CLI

```bash
aws secretsmanager get-secret-value \
  --profile devops-sandbox --region ap-southeast-2 \
  --secret-id /devops-refresher/staging/app/DB_PASS | jq .
```

- Task role can read/write `s3://$bucket/app/*` and list the bucket; enable SSM read if your app fetches SSM at runtime.

## Cleanup

```bash
terraform destroy -auto-approve
```
