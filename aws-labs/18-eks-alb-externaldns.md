# Lab 18 – EKS ALB + ExternalDNS

## Objectives

- Create IRSA roles for AWS Load Balancer Controller and ExternalDNS.
- Request an ACM certificate for the EKS app domain with DNS validation.
- Install the controllers via Helm using the IRSA roles.

## Steps

1. Apply Terraform in `aws-labs/18-eks-alb-externaldns/` with outputs from Lab 17:

```
cd aws-labs/18-eks-alb-externaldns
terraform init
terraform apply -auto-approve \
  -var oidc_provider_arn=$(cd ../17-eks-cluster && terraform output -raw oidc_provider_arn)
```

2. Install AWS Load Balancer Controller:

```
helm repo add eks https://aws.github.io/eks-charts
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$(cd ../17-eks-cluster && terraform output -raw cluster_name) \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$(terraform output -raw lbc_role_arn)
```

3. Install ExternalDNS:

```
helm repo add bitnami https://charts.bitnami.com/bitnami
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

Outputs:

- `certificate_arn`, `lbc_role_arn`, `externaldns_role_arn`
