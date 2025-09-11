# Lab 15 – EKS External Secrets (IRSA)

## Objective

Create a least‑privilege IRSA role for External Secrets Operator (ESO) to read config from SSM Parameter Store and Secrets Manager, then sync into Kubernetes Secrets for app consumption.

## Prerequisites

- EKS cluster with OIDC provider enabled (see `aws-labs/99-eks.md`).
- ESO installed in namespace `external-secrets` with ServiceAccount `external-secrets` (change below if different).
- AWS region set (pass as Terraform var `region`).

## Apply

```bash
cd aws-labs/15-eks-external-secrets
terraform init
terraform apply \
  -var region=$AWS_REGION \
  -var oidc_provider_arn=<oidc_provider_arn> \
  -var oidc_provider_url=<oidc_provider_url> \
  -var ssm_path_prefix=/devops-refresher/staging/app \
  -var secrets_prefix=/devops-refresher/staging/app \
  -auto-approve

echo "ESO_ROLE_ARN=$(terraform output -raw role_arn)"
```

Annotate the ESO controller ServiceAccount with the role arn:

```bash
kubectl -n external-secrets annotate sa external-secrets \
  eks.amazonaws.com/role-arn=$(terraform output -raw role_arn) \
  --overwrite
```

## ClusterSecretStore

Apply one or both (adjust `${AWS_REGION}`):

```bash
kubectl apply -f kubernetes/manifests/externalsecrets-clustersecretstore-parameterstore.yml
kubectl apply -f kubernetes/manifests/externalsecrets-clustersecretstore-secretsmanager.yml
```

## Demo App

Install chart with ESO enabled values for staging:

```bash
helm upgrade --install demo kubernetes/helm/demo-app \
  -f kubernetes/helm/demo-app/values-eks-staging.yaml
```

## Verify

- `kubectl get externalsecret -A` shows synced status.
- `kubectl get secret demo-app-env -o yaml` shows expected keys.
- Pod has env vars from `demo-app-env` via `envFrom`.
