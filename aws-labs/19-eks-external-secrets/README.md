# EKS External Secrets (IRSA)

## Objective

Create a least‑privilege IRSA role for External Secrets Operator (ESO) to read config from SSM Parameter Store and Secrets Manager, then sync into Kubernetes Secrets for app consumption.

## Prerequisites

- EKS cluster with OIDC provider enabled (see `aws-labs/17-eks-cluster.md`).
- ESO installed in namespace `external-secrets` with ServiceAccount `external-secrets` (change below if different).
- AWS region set (pass as Terraform var `region`).

## Apply

This lab auto-discovers the OIDC provider ARN/URL from Lab 17's remote state.

```bash
cd aws-labs/19-eks-external-secrets
terraform init
terraform apply -auto-approve

echo "ESO_ROLE_ARN=$(terraform output -raw role_arn)"
```

Notes:

- Overrides (optional):
  - `-var oidc_provider_arn=...` and `-var oidc_provider_url=...` to bypass remote state lookup.
  - `-var namespace=external-secrets` and `-var service_account=external-secrets` if you use custom names.
  - `-var ssm_path_prefix=/your/prefix` and `-var secrets_prefix=/your/prefix` (defaults to `/devops-refresher/staging/app`).
  - `-var aws_profile=devops-sandbox` if you use a non-default profile name.

Warning: Ensure Terraform uses the same AWS account as Lab 17. If you accidentally created resources in a different account, destroy them with the same credentials used originally, then re-run apply with `-var aws_profile=<correct-profile>` or `AWS_PROFILE=<correct-profile>`.

Annotate the ESO controller ServiceAccount with the role arn:

```bash
kubectl -n external-secrets annotate sa external-secrets \
  eks.amazonaws.com/role-arn=$(terraform output -raw role_arn) \
  --overwrite
```

## ClusterSecretStore

Apply one or both (adjust `${AWS_REGION}`):

```bash
kubectl apply -f aws-labs/kubernetes/manifests/externalsecrets-clustersecretstore-parameterstore.yml
kubectl apply -f aws-labs/kubernetes/manifests/externalsecrets-clustersecretstore-secretsmanager.yml
```

## Demo App

Install chart with ESO enabled values for staging:

```bash
helm upgrade --install demo aws-labs/kubernetes/helm/demo-app \
  -f aws-labs/kubernetes/helm/demo-app/values-eks-staging.yaml
```

## Verify

- `kubectl get externalsecret -A` shows synced status.
- `kubectl get secret demo-app-env -o yaml` shows expected keys.
- Pod has env vars from `demo-app-env` via `envFrom`.

## Validation

Run the validator:

```bash
bash aws-labs/scripts/validate-eks-external-secrets.sh
```
