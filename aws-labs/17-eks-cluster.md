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
aws eks update-kubeconfig --name $(terraform output -raw cluster_name) --region ap-southeast-2
kubectl get nodes
```

3. Outputs to pass to next labs:

- `oidc_provider_arn`, `oidc_provider_url` → used by 18/19 IRSA roles

Next labs:

- 18 – EKS ALB + ExternalDNS
- 19 – EKS External Secrets
- 20 – EKS App (Helm)

## Validation

Run: `aws-labs/scripts/validate-eks-cluster.sh`

## Versioning & Upgrades

- Default cluster version is 1.31 in this repo to avoid extended support windows.
- EKS only supports one-minor upgrades at a time. Example: 1.29 → 1.30 → 1.31 (do not skip directly).

Sequential upgrade example (run one step at a time and wait for ACTIVE):

```
# First: 1.29 -> 1.30
terraform apply -auto-approve -var kubernetes_version=1.30
aws-labs/scripts/validate-eks-cluster.sh

# Then: 1.30 -> 1.31
terraform apply -auto-approve -var kubernetes_version=1.31
aws-labs/scripts/validate-eks-cluster.sh
```

Notes:

- Core EKS managed add-ons (vpc-cni, coredns, kube-proxy) are installed by this lab and auto-select the latest compatible version for the cluster minor.
- After control plane upgrades, roll node groups (EKS usually rolls as needed; you can trigger a rollout from the console if desired).
- If Terraform replaces the cluster OIDC provider during an upgrade, re-apply IRSA roles in labs 18/19 with the new OIDC outputs:

```
cd aws-labs/18-eks-alb-externaldns
terraform apply -auto-approve \
  -var oidc_provider_arn=$(cd ../17-eks-cluster && terraform output -raw oidc_provider_arn)

cd ../19-eks-external-secrets
terraform apply -auto-approve \
  -var region=ap-southeast-2 \
  -var oidc_provider_arn=$(cd ../17-eks-cluster && terraform output -raw oidc_provider_arn) \
  -var oidc_provider_url=$(cd ../17-eks-cluster && terraform output -raw oidc_provider_url) \
  -var ssm_path_prefix=/devops-refresher/staging/app \
  -var secrets_prefix=/devops-refresher/staging/app
```
