# Lab 19 – EKS External Secrets

## Objectives

- Create a least‑privilege IRSA role for External Secrets Operator (ESO).
- Configure ClusterSecretStores for Parameter Store and Secrets Manager.

## Steps

1. Apply Terraform in `aws-labs/19-eks-external-secrets/` using OIDC from Lab 17:

```
cd aws-labs/19-eks-external-secrets
terraform init
terraform apply -auto-approve \
  -var region=ap-southeast-2 \
  -var oidc_provider_arn=$(cd ../17-eks-cluster && terraform output -raw oidc_provider_arn) \
  -var oidc_provider_url=$(cd ../17-eks-cluster && terraform output -raw oidc_provider_url) \
  -var ssm_path_prefix=/devops-refresher/staging/app \
  -var secrets_prefix=/devops-refresher/staging/app
```

Annotate the ESO controller ServiceAccount with the role arn:

```
kubectl -n external-secrets annotate sa external-secrets \
  eks.amazonaws.com/role-arn=$(terraform output -raw role_arn) --overwrite
```

2. Apply ClusterSecretStores:

```
kubectl apply -f aws-labs/kubernetes/manifests/externalsecrets-clustersecretstore-parameterstore.yml
 kubectl apply -f aws-labs/kubernetes/manifests/externalsecrets-clustersecretstore-secretsmanager.yml
```

## Validation

Run: `aws-labs/scripts/validate-eks-external-secrets.sh`

## Maintenance & Upgrades

- External Secrets Operator:
  - If installed via Helm, upgrade the chart to pick up fixes and provider updates.
  - Ensure the ESO controller ServiceAccount remains annotated with the IRSA role created by this lab.
  - Post‑upgrade, verify existing `ExternalSecret` resources are syncing (`kubectl get externalsecret -A`).
- IRSA policy scope:
  - This lab scopes SSM and Secrets Manager access to `/devops-refresher/<env>/<service>`. If paths change, update the Terraform and re‑apply; ESO will continue syncing.
- Rotation:
  - After rotating secrets in Secrets Manager, ESO will refresh the target Secret on the next cycle (default 1h). Force a re‑sync by deleting the synced Secret or toggling the ExternalSecret.
