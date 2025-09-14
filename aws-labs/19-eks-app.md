# Lab 20 – EKS App (Terraform, zero‑flags)

## What this lab does

- Deploys the demo app to EKS using the in‑repo Helm chart, via Terraform only (no kubectl/helm CLI needed).
- Injects all required runtime config directly:
  - S3 bucket, RDS host/port/user/name, Redis host/port from labs 08/09/10 remote state
  - DB_PASS read from Secrets Manager (created by lab 09)
- Configures ALB Ingress with the ACM cert from lab 18 and adds healthcheck annotations
- Opens RDS:5432 and Redis:6379 from the VPC CIDR via Terraform‑managed security group rules
- Does NOT use Security Groups for Pods (SGP) – avoids pod‑ENI scheduling issues

## Prereqs

- Lab 17 – EKS Cluster
- Lab 18 – EKS ALB + ExternalDNS (installs the AWS Load Balancer Controller and issues the ACM cert)
- Labs 08/09/10 – S3/RDS/Redis (provide outputs/secret the app consumes)

## Steps (copy/paste)

1. Apply lab 17 (once per environment)

```
terraform -chdir=aws-labs/17-eks-cluster apply --auto-approve
```

2. Apply lab 18 (ALB + IAM + ACM)

```
terraform -chdir=aws-labs/18-eks-alb-externaldns apply --auto-approve
```

3. Apply this lab (app)

```
terraform -chdir=aws-labs/20-eks-app init
terraform -chdir=aws-labs/20-eks-app apply --auto-approve
terraform -chdir=aws-labs/20-eks-app output -raw ingress_hostname
```

## Validate

```
kubectl -n demo rollout status deploy/demo-demo-app --timeout=120s
curl -sI https://demo-node-app-eks.aws.deanlofts.xyz | head -n 2
curl -s  https://demo-node-app-eks.aws.deanlofts.xyz/healthz | head -n 1
```

Expected:

- Pod 1/1 Running
- HTTPS root 200 (overview) and /healthz = ok

## Destroy (reverse order)

```
terraform -chdir=aws-labs/20-eks-app destroy --auto-approve
terraform -chdir=aws-labs/18-eks-alb-externaldns destroy --auto-approve
terraform -chdir=aws-labs/17-eks-cluster destroy --auto-approve
```

## Troubleshooting (copy/paste)

- Ingress has no ADDRESS
  - Ensure lab 18 completed; LBC IAM must include DescribeListenerAttributes/CreateRule
- Pod Pending with Insufficient vpc.amazonaws.com/pod-eni
  - SGP is not used here by design. If you added one, remove it: `kubectl delete securitygrouppolicy -n demo app-sg`
- HTTPS 502
  - RDS/Redis SGs must allow from VPC CIDR; this lab manages ingress rules automatically. Re‑apply this lab.
- HTTPS 401 on protected routes
  - App enforces auth for /readyz, /selftest, /db, /cache. Use APP_AUTH_SECRET (see app docs) or hit public endpoints: `/`, `/healthz`.

## Postmortem – how teams get stuck here

- SGP without enabling pod ENIs causes Pending scheduling
- Missing LBC permissions prevent ALB provisioning
- ESO CRD timing/ordering creates “CRD not found” noise
- RDS/Redis SGs restricted only to app SG (ECS) but not EKS nodes

This lab removes SGP/ESO dependencies and automates SG ingress to keep the flow simple and reliable.
