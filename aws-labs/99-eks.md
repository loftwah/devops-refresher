# EKS (Kubernetes on AWS)

## Objectives

- Create an EKS cluster in the existing VPC private subnets.
- Deploy a sample app and expose it via ALB Ingress Controller.
- Set up external-dns and Container Insights (logs/metrics).

## Decisions

- Cluster: one managed node group (t3.medium) for staging.
- Networking: private subnets for nodes; public subnets for ALB.
- Ingress: AWS Load Balancer Controller (ALB Ingress Controller).
- DNS: external-dns manages route53 records in `aws.deanlofts.xyz`.
- Observability: CloudWatch Container Insights and Fluent Bit.
- Config/Secrets: SSM Parameter Store for non-secrets; Secrets Manager for secrets, surfaced into pods via Secrets Store CSI Driver (AWS provider) or external-secrets.

## Tasks

1. EKS cluster + node group (Terraform: `aws_eks_cluster`, `aws_eks_node_group`).
2. IAM roles: cluster, node group, and IRSA for controllers (ALB, external-dns, metrics-server).
3. Install via Helm:
   - aws-load-balancer-controller (IRSA bound)
   - external-dns (scoped to the delegated hosted zone)
   - metrics-server
   - secrets-store-csi-driver + aws provider (for SSM/Secrets)
4. Deploy sample app (Service `ClusterIP`, Ingress with annotations for ALB; TLS optional for lab).

## Acceptance Criteria

- `kubectl get nodes` shows Ready nodes.
- Ingress provisions an ALB; DNS record resolves and serves the app.
- Logs and metrics visible in CloudWatch.
- Pod has environment/config from SSM; secret mounted via CSI driver.

## Hints

- Use IRSA for least privilege: annotate service accounts with the role ARN.
- Tag subnets for ALB discovery (`kubernetes.io/role/elb` on public; `kubernetes.io/role/internal-elb` on private if needed).
- Reuse VPC outputs from the VPC lab via `terraform_remote_state`.
- For SSM/Secrets:
  - Grant IRSA role `ssm:GetParameters*` and `secretsmanager:GetSecretValue` on the specific paths/ARNS.
  - Mount via secrets-store-csi-driver or sync into native K8s Secrets with external-secrets.
- If using CloudFront in front of the ALB, ensure correct health check path and HTTP->HTTPS redirects.
