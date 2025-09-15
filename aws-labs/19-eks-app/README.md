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
  - `image.repository` and `image.tag` from variables (defaults to ECR `staging`)
  - Ingress via ALB, host from `var.host`, and cert from Lab 18
  - `extraEnv: DEPLOY_PLATFORM=eks` so the app banner shows EKS
  - Optional `externalSecrets` block if `enable_externalsecrets=true`

## Variables

- `namespace` (default `demo`), `release_name` (default `demo-eks`)
- `image_repository`, `image_tag` (default `staging`)
- `host`, `ingress_enabled`
- `enable_externalsecrets` (default `false`)

## Cleanup

```bash
terraform destroy -auto-approve
```

## Existing release collision

If you previously installed the chart as `demo`, either:

- Set `-var 'release_name=demo'` when applying this lab, or
- Uninstall the existing release first:

```bash
helm -n demo uninstall demo || true
```


