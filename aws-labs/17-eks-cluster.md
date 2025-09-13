# Lab 17 – EKS Cluster

## Objectives

- Provision an EKS cluster in existing VPC private subnets.
- Create a managed node group.
- Enable IRSA by creating the cluster OIDC provider.
- Tag subnets for ALB discovery and cluster association.

## Steps

1. Apply the Terraform in `aws-labs/17-eks-cluster/`:

```
cd aws-labs/17-eks-cluster
terraform init
terraform apply -auto-approve
```

2. Update kubeconfig and verify:

```
aws eks update-kubeconfig --name $(terraform output -raw cluster_name) --region us-east-1
kubectl get nodes
```

3. Outputs to pass to next labs:

- `oidc_provider_arn`, `oidc_provider_url` → used by 18/19 IRSA roles

Next labs:

- 18 – EKS ALB + ExternalDNS
- 19 – EKS External Secrets
- 20 – EKS App (Helm)
