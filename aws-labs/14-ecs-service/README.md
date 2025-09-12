# Lab 14 – ECS Service (App)

## Objectives

- Deploy the app on ECS Fargate, attach to the ALB target group, and use existing IAM roles.

## Prerequisites

- Lab 13 ECS Cluster: `cluster_arn`.
- Lab 01 VPC: `private_subnet_ids`.
- Lab 07 Security Groups: `app_sg_id`.
- Lab 12 ALB: `tg_arn`.
- Lab 06 IAM: `execution_role_arn`, `task_role_arn`.

## Apply

```bash
cd aws-labs/14-ecs-service
terraform init
terraform apply \
  -var cluster_arn=$(cd ../13-ecs-cluster && terraform output -raw cluster_arn) \
  -var 'subnet_ids=["subnet-aaaa","subnet-bbbb"]' \
  -var 'security_group_ids=['"$(cd ../07-security-groups && terraform output -raw app_sg_id)"']' \
  -var target_group_arn=$(cd ../12-alb && terraform output -raw tg_arn) \
  -var execution_role_arn=$(cd ../06-iam && terraform output -raw execution_role_arn) \
  -var task_role_arn=$(cd ../06-iam && terraform output -raw task_role_arn) \
  -var image=<account>.dkr.ecr.<region>.amazonaws.com/devops-refresher:staging \
  -var container_port=3000 \
  -var desired_count=1 \
  -auto-approve
```

To map secrets (DB_PASS, REDIS_PASS):

```bash
-var 'secrets=[{name="DB_PASS",valueFrom="arn:aws:secretsmanager:...:secret:/devops-refresher/staging/app/DB_PASS-xxxx"},{name="REDIS_PASS",valueFrom="arn:aws:secretsmanager:...:secret:/devops-refresher/staging/app/REDIS_PASS-xxxx"}]'
```

## Outputs

- `service_name`, `task_definition_arn`.

## Image tag requirements and troubleshooting

- The service defaults to using the ECR repository URL from Lab 03 with the `:staging` tag when `-var image` is not provided.
- Ensure your build process pushes at least two tags for the app image:
  - An immutable tag, e.g., the short git SHA.
  - An environment tag used by ECS, e.g., `staging`.
- Example build/push flow:

```bash
AWS_PROFILE=devops-sandbox AWS_REGION=ap-southeast-2 \
  ./build-and-push.sh   # tags and pushes :<sha> and :staging

# Verify the tag exists
aws ecr describe-images \
  --repository-name demo-node-app \
  --query 'imageDetails[].imageTags' \
  --region ap-southeast-2 --profile devops-sandbox
```

Common error
- `CannotPullContainerError: ... demo-node-app:staging: not found` means `:staging` was not pushed to ECR. Push the tag (see above) and re-apply the service.


## Cleanup

```bash
terraform destroy -auto-approve
```
