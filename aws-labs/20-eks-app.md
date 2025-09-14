# Lab 20 – EKS App (Terraform)

## Objectives

- Deploy the demo app to EKS using the in-repo Helm chart, driven by Terraform (no kubectl/helm required).
- Use External Secrets Operator to source env from SSM/Secrets.
- Expose via ALB Ingress using the ACM certificate from Lab 18.

## Steps (zero flags)

1. Apply lab 18 (ALB + IAM + ACM; LBC installs by default):

```
terraform -chdir=aws-labs/18-eks-alb-externaldns apply --auto-approve
```

2. Deploy the app via Terraform:

```
terraform -chdir=aws-labs/20-eks-app init
terraform -chdir=aws-labs/20-eks-app apply --auto-approve
terraform -chdir=aws-labs/20-eks-app output -raw ingress_hostname
```

That deploys image `139294524816.dkr.ecr.ap-southeast-2.amazonaws.com/demo-node-app:staging`, enables an ALB Ingress with the ACM cert from lab 18, and prints the ALB DNS.

If ExternalDNS is installed, `demo-node-app-eks.aws.deanlofts.xyz` will resolve automatically; otherwise, hit the ALB hostname directly.

Notes:

- Security Groups for Pods: apply `aws-labs/kubernetes/manifests/sgp-app.yml` (replace placeholder SG) if you enable SGP.
- External Secrets: disabled by default in this lab; enable later by setting `enable_externalsecrets=true` in `aws-labs/20-eks-app/variables.tf` and re-applying.

## Validation

Run: `aws-labs/scripts/validate-eks-app.sh`

## Operations & Maintenance

- Deployments:
  - Promote a new image by updating the tag in values or with `--set image.tag=<sha>` and `helm upgrade`.
  - Rollback: `helm -n demo rollback demo <revision>`; view history with `helm -n demo history demo`.
- Configuration:
  - Non‑secrets from SSM and secrets from Secrets Manager are synced by ESO; the pod consumes a single K8s Secret via `envFrom`.
  - Update SSM/Secrets values and let ESO sync (or force re‑sync); then restart the Deployment if the app only reads env at startup.
- Ingress & TLS:
  - ACM cert is DNS‑validated and auto‑renews. Keep the Ingress host and Route 53 zone stable; ExternalDNS maintains records from the Ingress.
