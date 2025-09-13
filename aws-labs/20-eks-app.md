# Lab 20 – EKS App (Helm)

## Objectives

- Deploy the demo app to EKS using the in-repo Helm chart and values.
- Use External Secrets Operator to source env from SSM/Secrets.
- Expose via ALB Ingress using the ACM certificate from Lab 18.

## Steps

1. Ensure controllers are installed (LBC, ExternalDNS, ESO) and SecretStores applied.

2. Deploy app with staging values:

```
helm upgrade --install demo aws-labs/kubernetes/helm/demo-app \
  -n demo --create-namespace \
  -f aws-labs/kubernetes/helm/demo-app/values-eks-staging-app.yaml \
  --set ingress.certificateArn=$(cd aws-labs/18-eks-alb-externaldns && terraform output -raw certificate_arn)
```

3. Verify:

- `kubectl get externalsecret -A` shows synced.
- `kubectl -n demo get ingress demo -o wide` shows ALB address.
- `curl -sSI https://demo-node-app-eks.aws.deanlofts.xyz/healthz` returns 200.

Notes:

- Security Groups for Pods: apply `aws-labs/kubernetes/manifests/sgp-app.yml` once you replace the placeholder SG ID with the `app_sg_id` output from Lab 07.

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
