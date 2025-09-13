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

## Prerequisites

- EKS cluster reachable with `kubectl` and `helm`.
- Cluster OIDC provider created for IRSA.
- IAM permission to create roles/policies for controllers and app service accounts.

## Tasks

1. Cluster + Node Group (Terraform)

- Create `aws_eks_cluster` and `aws_eks_node_group` in private subnets; tag subnets for ALB discovery.

2. OIDC Provider for IRSA (Terraform)

```hcl
data "aws_eks_cluster" "this" { name = var.cluster_name }

resource "aws_iam_openid_connect_provider" "this" {
  url             = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [var.oidc_thumbprint]
}
```

3. Controllers via IRSA + Helm

- AWS Load Balancer Controller (Ingress → ALB):

```hcl
data "aws_iam_policy_document" "alb_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals { type = "Federated" identifiers = [aws_iam_openid_connect_provider.this.arn] }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "alb" {
  name               = "eks-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.alb_trust.json
}

# Attach the recommended AWS policy JSON from controller docs
resource "aws_iam_policy" "alb" {
  name   = "AWSLoadBalancerControllerPolicy"
  policy = file("kubernetes/policies/aws-load-balancer-controller.json") # sync from controller docs
}

resource "aws_iam_role_policy_attachment" "alb" {
  role       = aws_iam_role.alb.name
  policy_arn = aws_iam_policy.alb.arn
}
```

Install options:

Option A — Helm with values file

```bash
helm repo add eks https://aws.github.io/eks-charts
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system -f kubernetes/helm/aws-load-balancer-controller-values.yml
```

Option B — Inline flags (no values file)

```bash
helm repo add eks https://aws.github.io/eks-charts
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$ALB_ROLE_ARN
```

- Secrets Store CSI Driver + AWS provider (SSM/Secrets → K8s Secret):

```hcl
data "aws_iam_policy_document" "sscsid_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals { type = "Federated" identifiers = [aws_iam_openid_connect_provider.this.arn] }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:csi-secrets-store-provider-aws"]
    }
  }
}

resource "aws_iam_role" "sscsid" {
  name               = "eks-secrets-store-aws-provider"
  assume_role_policy = data.aws_iam_policy_document.sscsid_trust.json
}

resource "aws_iam_policy" "sscsid" {
  name   = "SecretsStoreAWSProviderAccess"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {"Effect":"Allow","Action":["secretsmanager:GetSecretValue","secretsmanager:DescribeSecret"],"Resource":"*"},
    {"Effect":"Allow","Action":["ssm:GetParameter","ssm:GetParameters","ssm:GetParametersByPath"],"Resource":"*"}
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "sscsid" {
  role       = aws_iam_role.sscsid.name
  policy_arn = aws_iam_policy.sscsid.arn
}
```

Verification:

- `kubectl -n kube-system get deploy aws-load-balancer-controller` shows Ready replicas.
- Create a basic Ingress; controller logs show ALB/TG creation; ALB appears in AWS console.
- Common failures: missing IAM permissions (AccessDenied), subnets not tagged for ELB, or ACM cert not in the same region.

Install options:

Option A — Helm for driver + upstream manifests for provider

```bash
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm upgrade --install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
  -n kube-system -f kubernetes/helm/secrets-store-csi-driver-values.yml

kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml
kubectl -n kube-system apply -f kubernetes/manifests/secrets-store-csi-driver-provider-aws-sa-patch.yml
```

Option B — Helm for both (driver and provider)

- Some teams prefer managing everything via Helm. If you package the provider manifests into a local chart or consume a provider Helm chart, set the service account annotation in values:

```yaml
# values.yml (example for provider chart; Helm defaults to values.yaml)
serviceAccount:
  create: true
  name: secrets-store-csi-driver-provider-aws
  annotations:
    eks.amazonaws.com/role-arn: ${SSCSID_ROLE_ARN}
```

Then install with: `helm upgrade --install aws-provider <repo/chart> -n kube-system -f values.yaml`

Notes:

- The upstream provider docs commonly use `kubectl apply` with a static manifest. Helm unifies lifecycle and drift management but requires a chart source; either vendor the manifests or use a maintained chart.
- Regardless of method, the provider service account must have the IRSA role annotation.

- External Secrets Operator (recommended for env vars): see `aws-labs/99-eks-external-secrets.md` for the IRSA role/policy and end-to-end steps. With ESO, the controller reads from AWS and syncs into a Secret; application pods `envFrom` that Secret and typically don’t need AWS permissions.

Verification:

- `kubectl -n kube-system get ds -l app=secrets-store-csi-driver` shows nodes scheduled.
- Define a `SecretProviderClass` and Deployment that references it; confirm a Kubernetes Secret is created (if `syncSecret.enabled=true`) and env vars are present in the pod.
- Common failures: missing IRSA on provider SA (no AWS creds), policy denies `secretsmanager:GetSecretValue`/`ssm:GetParameters*`, or wrong object names/paths.

- Optional: ExternalDNS (IRSA scoped to your hosted zone IDs), metrics-server.

4. App Deployment

- Create Namespace, ServiceAccount (IRSA for app), Deployment, Service, and Ingress annotated for ALB. See ALB lab for Ingress example.
- Use Secrets Store CSI Driver to materialize SSM Parameter Store values and Secrets Manager secrets into a K8s Secret, then `envFrom` it. See Parameter Store lab for a full example.

5. Security Groups for Pods (use app_sg)

- Goal: Reuse the shared `app_sg` from Lab 07 for EKS pods so only the ALB can reach the app port.
- Prereq: AWS VPC CNI add-on with Security Groups for Pods enabled (CRD present).
  - Verify: `kubectl get crd securitygrouppolicies.vpcresources.k8s.aws`
- Get the shared SG ID from Lab 07:

```bash
APP_SG_ID=$(cd ../07-security-groups && terraform output -raw app_sg_id)
echo "$APP_SG_ID"
```

- Apply a SecurityGroupPolicy that selects your pods by label and attaches `app_sg`:

```yaml
# kubernetes/manifests/sgp-app.yml
apiVersion: vpcresources.k8s.aws/v1beta1
kind: SecurityGroupPolicy
metadata:
  name: app-sg
  namespace: demo
spec:
  podSelector:
    matchLabels:
      app: demo-node-app
  securityGroups:
    groupIds:
      - ${APP_SG_ID} # staging-app from Lab 07
```

- Ensure your Deployment uses the matching label and namespace:

```yaml
# excerpt from Deployment
metadata:
  name: demo-node-app
  namespace: demo
  labels:
    app: demo-node-app
spec:
  selector:
    matchLabels:
      app: demo-node-app
  template:
    metadata:
      labels:
        app: demo-node-app
```

Notes

- ALB uses `alb_sg`; pods use `app_sg`. Lab 07 already allows the container port only from `alb_sg` to `app_sg`.
- AWS Load Balancer Controller registers pod IPs (target type `ip`) so the ALB → pods path honors these SGs.
- If the CRD is missing, upgrade/install the VPC CNI add-on with Security Groups for Pods enabled.

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
