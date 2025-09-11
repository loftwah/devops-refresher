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

- Keep this cluster reusable for multiple services in the same environment.

## Cleanup

```bash
terraform destroy -auto-approve
```
