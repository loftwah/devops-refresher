# Lab 13 – ECS Cluster

## Objectives

- Create an ECS cluster decoupled from any specific application service.

## Apply

```bash
cd aws-labs/13-ecs-cluster
terraform init
terraform apply -auto-approve
```

## Outputs

- `cluster_name`, `cluster_arn`, and a CloudWatch Logs group for consistency.

## Notes

- What Terraform Actually Creates (main.tf):
  - `aws_cloudwatch_log_group.ecs` named `/aws/ecs/devops-refresher-staging` with 30‑day retention.
  - `aws_ecs_cluster.this` named `devops-refresher-staging` with Container Insights enabled.
  - Outputs: `cluster_name`, `cluster_arn`, `log_group_name`.

- Keep this cluster reusable for multiple services in the same environment.

## Cleanup

```bash
terraform destroy -auto-approve
```
