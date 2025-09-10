# Lab 13 – CloudFront for ECS/EKS Apps

This stack issues ACM certs in us-east-1, creates two CloudFront distributions (one for ECS, one for EKS), and publishes Route 53 aliases for:

- `demo-node-app-ecs.aws.deanlofts.xyz`
- `demo-node-app-eks.aws.deanlofts.xyz`

Inputs

- `ecs_alb_dns_name`: ALB DNS name for the ECS service
- `eks_alb_dns_name`: ALB DNS name for the EKS Ingress
- `hosted_zone_name`/`hosted_zone_id`: the `aws.deanlofts.xyz` zone

Notes

- Certificates must be in `us-east-1` to be usable by CloudFront; we configure an aliased AWS provider for that region.
- We use managed policies to effectively disable caching for dynamic APIs; you can swap to custom policies later.

Apply

```
cd aws-labs/13-cloudfront
terraform init
terraform apply -var ecs_alb_dns_name=<ecs-alb> -var eks_alb_dns_name=<eks-alb>
```
