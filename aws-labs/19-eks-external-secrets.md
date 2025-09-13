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
