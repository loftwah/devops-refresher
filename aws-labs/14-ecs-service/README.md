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

## Cleanup

```bash
terraform destroy -auto-approve
```
