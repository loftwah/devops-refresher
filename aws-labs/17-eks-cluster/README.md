# Lab 17 – EKS Cluster (Terraform)

## Objective

Provision an EKS cluster and managed node group in the existing VPC private subnets, tag subnets for ALB discovery, and create the cluster OIDC provider for IRSA.

## What This Stack Creates

- IAM roles for the EKS control plane and node group (with recommended managed policies).
- `aws_eks_cluster` with API endpoint public+private, using both public and private subnets for control plane ENIs.
- `aws_eks_node_group` in private subnets.
- Subnet tags:
  - Public: `kubernetes.io/role/elb=1` and `kubernetes.io/cluster/<name>=shared`
  - Private: `kubernetes.io/cluster/<name>=shared`
- OIDC provider for IRSA (outputs ARN/URL).

## Prerequisites

- Lab 01 (VPC) applied with outputs available in remote state.
- AWS CLI auth for the configured profile.

## Apply

```
cd aws-labs/17-eks-cluster
terraform init
terraform apply -auto-approve
```

Outputs:

- `cluster_name`, `cluster_endpoint`
- `oidc_provider_arn`, `oidc_provider_url`

## Kubeconfig

```
aws eks update-kubeconfig \
  --name $(terraform output -raw cluster_name) \
  --region ap-southeast-2

kubectl get nodes
```

## Next

- Lab 18 – EKS ALB + ExternalDNS: IRSA roles and ACM, then install controllers.
- Lab 19 – EKS External Secrets: IRSA role for ESO and ClusterSecretStores.
- Lab 20 – EKS App: Deploy the application Helm chart.

Notes:

- If OIDC thumbprint differs in your region/account, override `-var oidc_thumbprint=...`.
- Subnet tags can take a minute to propagate; controller discovery relies on them.
