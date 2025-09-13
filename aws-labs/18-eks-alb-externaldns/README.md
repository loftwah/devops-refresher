# EKS ALB + ExternalDNS (IRSA + ACM)

## Objectives

- Enable Kubernetes-managed ALB via AWS Load Balancer Controller (LBC).
- Let ExternalDNS manage Route53 records from Ingress hosts.
- Issue an ACM certificate for `demo-node-app-eks.aws.deanlofts.xyz` with DNS validation.

## Prerequisites

- An EKS cluster with OIDC provider enabled (eksctl or `aws eks update-cluster-config --identity-provider-configs ...`).
- Route53 public hosted zone `aws.deanlofts.xyz` delegated from your apex domain.
- kubectl/helm access to the cluster.

## Terraform (IAM + ACM)

This module creates:

- IRSA roles for:
  - AWS Load Balancer Controller (trusts `system:serviceaccount:kube-system:aws-load-balancer-controller`).
  - ExternalDNS (trusts `system:serviceaccount:external-dns:external-dns`).
- IAM policies (LBC recommended baseline; ExternalDNS limited to the child zone).
- ACM certificate for the EKS app domain with DNS validation.

Apply:

This lab auto-discovers the cluster OIDC provider ARN from Lab 17's remote state.

```bash
cd aws-labs/18-eks-alb-externaldns
terraform init
terraform apply -auto-approve
```

Notes:

- Override any defaults if needed:
  - `-var hosted_zone_name=aws.deanlofts.xyz`
  - `-var eks_domain_fqdn=demo-node-app-eks.aws.deanlofts.xyz`
  - `-var oidc_provider_arn=...` (only if you want to bypass remote state lookup)

Outputs:

- `certificate_arn` – Use in your Ingress annotation.
- `lbc_role_arn` – Annotate the LBC service account.
- `externaldns_role_arn` – Annotate the ExternalDNS service account.

## Controllers

No manual Helm steps are required. This lab installs the AWS Load Balancer Controller and ExternalDNS via Terraform, using the IRSA roles it provisions. Disable with `-var manage_k8s=false` if you want to manage them yourself.

## Example Ingress (demo app)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo
  namespace: app
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/certificate-arn: <paste terraform output certificate_arn>
    # Optional: use existing ALB SG from Lab 07
    # alb.ingress.kubernetes.io/security-groups: <sg-xxxx>
    # alb.ingress.kubernetes.io/healthcheck-path: /healthz
spec:
  rules:
    - host: demo-node-app-eks.aws.deanlofts.xyz
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 3000
```

## Validation

### Automated

Run the lab validator to ensure IAM roles exist and the ACM certificate is ISSUED:

```bash
bash aws-labs/scripts/validate-eks-alb-externaldns.sh
```

### Manual (optional, after you install controllers and an Ingress)

- `kubectl get ingress -A` – Ingress shows an address (ALB DNS).
- `dig +short demo-node-app-eks.aws.deanlofts.xyz` resolves to the ALB.
- `curl -I http://demo-node-app-eks.aws.deanlofts.xyz/healthz` shows 301 → HTTPS.
- `curl -sS https://demo-node-app-eks.aws.deanlofts.xyz/healthz` returns 200.

## Cleanup

- Delete the Ingress to remove the ALB.
- Helm uninstall `external-dns` and `aws-load-balancer-controller`.
- `terraform destroy` in this lab folder.
