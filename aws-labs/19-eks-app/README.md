# Lab 19 – EKS App (Helm deploy via Terraform)

## Objective

Deploy the demo app Helm chart to the EKS cluster using Terraform’s `helm_release`, wiring defaults consistent with Lab 20’s pipeline.

## Dependencies

- Lab 17 – EKS Cluster (exports `cluster_name`)
- Lab 18 – EKS ALB + ExternalDNS (exports `certificate_arn`)
- Optional: External Secrets Operator installed and `ClusterSecretStore` named `aws-parameterstore`

## Backend and Providers

State is stored in S3 via `backend.tf` with the same convention as other labs. AWS provider uses `ap-southeast-2` and `devops-sandbox` by default.

## Apply

```bash
cd aws-labs/19-eks-app
terraform init
terraform apply -auto-approve
```

## What it does

- Looks up EKS cluster (Lab 17) and ALB cert (Lab 18) via remote state
- Deploys Helm chart `aws-labs/kubernetes/helm/demo-app` with:
  - `image.repository` and immutable `image.digest` (preferred). The CI pipeline resolves and passes the digest.
  - Ingress via ALB, host from `var.host`, and cert from Lab 18
  - `env` includes `DEPLOY_PLATFORM=eks` so the app banner shows EKS
  - Optional `externalSecrets` block if `enable_externalsecrets=true` (default: false)
  - ServiceAccount annotated with IRSA for S3 writes; outputs `app_irsa_role_arn` for reuse by the CI/CD lab

## Variables

- `namespace` (default `demo`), `release_name` (default `demo-eks`)
- `image_repository`, `image_tag` (when set, should be a sha256 image digest; the pipeline sets this)
- `host`, `ingress_enabled`
- `enable_externalsecrets` (default `false`)

## Cleanup

```bash
terraform destroy -auto-approve
```

## Existing release collision

If you previously installed another release (e.g. `demo`) in the same namespace, uninstall it first so Terraform manages a single release (`demo-eks` by default):

```bash
helm -n demo uninstall demo || true

## Notes

- This lab expects exactly one Helm release per environment for the app (default: `demo-eks`). Keeping a single release avoids DNS/ALB drift and confusion.
- External Secrets Operator is optional. Leave `enable_externalsecrets=false` until you install ESO and a ClusterSecretStore.
```
