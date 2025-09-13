# Lab 20 – EKS App (Helm)

This lab deploys the demo app to the EKS cluster using the in-repo Helm chart and values. No Terraform is required in this lab — it’s a Helm deploy using the chart under `aws-labs/kubernetes/helm/demo-app`.

## Prerequisites

- Labs 17–19 applied (EKS cluster, ALB/ExternalDNS + ACM, External Secrets + SecretStores).
- kubeconfig for the cluster: `aws eks update-kubeconfig --name $(cd ../17-eks-cluster && terraform output -raw cluster_name) --region ap-southeast-2`

## Deploy (one-liner)

```
helm upgrade --install demo aws-labs/kubernetes/helm/demo-app \
  -n demo --create-namespace \
  -f aws-labs/kubernetes/helm/demo-app/values-eks-staging-app.yaml \
  --set ingress.certificateArn=$(cd ../18-eks-alb-externaldns && terraform output -raw certificate_arn)
```

- The values file sets `image.repository` and `image.tag=staging`. Override with `--set image.tag=<sha>` to deploy an immutable tag built by CI.
- If you’re using the EKS CodePipeline (Lab 21), it performs the same Helm command automatically and sets the tag to the short commit SHA.

## Helper Script

Run the convenience script instead of typing the full command:

```
aws-labs/scripts/deploy-eks-app.sh
```

Options (env vars):

- `IMAGE_REPO` (optional): override image repo
- `IMAGE_TAG` (optional): override image tag
- `NAMESPACE` (default `demo`), `RELEASE_NAME` (default `demo`)

## Validate

- App/Ingress/HTTPS: `aws-labs/scripts/validate-eks-app.sh`
- Or run everything: `aws-labs/scripts/validate-labs.sh`

## Notes

- This lab is a Helm-only deploy, so there is no Terraform folder here. The main doc is also available at `aws-labs/20-eks-app.md`.
