# Lab 16 – EKS ALB + ExternalDNS (IRSA + ACM)

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

```bash
cd aws-labs/16-eks-alb-externaldns
terraform init
terraform apply \
  -var oidc_provider_arn=arn:aws:iam::<account-id>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<id> \
  -var hosted_zone_name=aws.deanlofts.xyz \
  -var eks_domain_fqdn=demo-node-app-eks.aws.deanlofts.xyz \
  -auto-approve
```

Outputs:

- `certificate_arn` – Use in your Ingress annotation.
- `lbc_role_arn` – Annotate the LBC service account.
- `externaldns_role_arn` – Annotate the ExternalDNS service account.

## Install AWS Load Balancer Controller

Using Helm (values inline for clarity):

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

kubectl create namespace kube-system --dry-run=client -o yaml | kubectl apply -f - || true

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<your-eks-cluster-name> \
  --set image.repository=602401143452.dkr.ecr.<region>.amazonaws.com/amazon/aws-load-balancer-controller \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$(terraform output -raw lbc_role_arn)
```

Notes:

- Ensure the ECR repository account (602401143452) matches your region for the controller image.
- If you prefer to re-use a pre-created SA, set `serviceAccount.create=false` and annotate it with the role ARN.

## Install ExternalDNS

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

kubectl create namespace external-dns --dry-run=client -o yaml | kubectl apply -f - || true

helm upgrade --install external-dns bitnami/external-dns \
  -n external-dns \
  --set provider=aws \
  --set policy=upsert-only \
  --set txtOwnerId=devops-refresher-staging \
  --set domainFilters[0]=aws.deanlofts.xyz \
  --set serviceAccount.create=true \
  --set serviceAccount.name=external-dns \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$(terraform output -raw externaldns_role_arn)
```

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

- `kubectl get ingress -A` – Ingress shows an address (ALB DNS).
- `dig +short demo-node-app-eks.aws.deanlofts.xyz` resolves to the ALB.
- `curl -I http://demo-node-app-eks.aws.deanlofts.xyz/healthz` shows 301 → HTTPS.
- `curl -sS https://demo-node-app-eks.aws.deanlofts.xyz/healthz` returns 200.

## Cleanup

- Delete the Ingress to remove the ALB.
- Helm uninstall `external-dns` and `aws-load-balancer-controller`.
- `terraform destroy` in this lab folder.
