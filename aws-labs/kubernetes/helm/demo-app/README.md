# demo-app Helm chart

This chart deploys a simple demo app. It supports two config patterns:

- Explicit `env`: set values in `values.yaml` (good for local/dev)
- External Secrets Operator (ESO): source all env from AWS SSM/Secrets Manager without committing them to Git

## Prereqs

- EKS cluster
- External Secrets Operator installed and an AWS `SecretStore`/`ClusterSecretStore` configured
  - Install ESO: https://external-secrets.io/latest/introduction/getting-started/
  - Example ClusterSecretStore (Parameter Store): https://external-secrets.io/latest/provider/aws-parameter-store/
- IRSA:
  - When using ESO (recommended): grant IRSA to the ESO controller's ServiceAccount so it can read SSM/Secrets; the app ServiceAccount does NOT need AWS permissions.
  - When NOT using ESO (e.g., Secrets Store CSI Driver or app reads AWS directly): grant IRSA to the app ServiceAccount with read permissions to the required SSM paths and Secrets ARNs.

## Values overview

- `externalSecrets.enabled`: when true, chart creates an `ExternalSecret` and Deployment uses `envFrom` the resulting Secret
- `externalSecrets.storeRef`: reference your (Cluster)SecretStore by kind/name
- `externalSecrets.targetSecretName`: the Secret name synced by ESO and used by the pod
- `externalSecrets.dataFrom` / `externalSecrets.data`: select which params/secrets to sync
- When `externalSecrets.enabled=false`, use `env` to set explicit key/values
- `env`: can be used either alone or alongside `externalSecrets.enabled=true` (in which case `env` is merged with `envFrom` Secret content)

## Quick start

Explicit env (no ESO):

```bash
helm upgrade --install demo aws-labs/kubernetes/helm/demo-app \
  --set image.repository=public.ecr.aws/docker/library/nginx \
  --set image.tag=stable \
  --set env[0].name=LOG_LEVEL --set env[0].value=info
```

Using ESO with Parameter Store prefix:

```bash
# Ensure you have a ClusterSecretStore named aws-parameterstore
helm upgrade --install demo aws-labs/kubernetes/helm/demo-app \
  --set externalSecrets.enabled=true \
  --set externalSecrets.storeRef.kind=ClusterSecretStore \
  --set externalSecrets.storeRef.name=aws-parameterstore \
  --set externalSecrets.targetSecretName=demo-app-env \
  --set-json 'externalSecrets.dataFrom=[{"extract":{"key":"/devops-refresher/staging/app"}}]'
```

Or use the provided example values for staging:

```bash
helm upgrade --install demo aws-labs/kubernetes/helm/demo-app -f aws-labs/kubernetes/helm/demo-app/values-eks-staging.yaml
```

Mixing in a single secret key (e.g., DB_PASS from Secrets Manager):

```bash
helm upgrade --install demo aws-labs/kubernetes/helm/demo-app \
  --set externalSecrets.enabled=true \
  --set externalSecrets.targetSecretName=demo-app-env \
  --set-json 'externalSecrets.data=[{"secretKey":"DB_PASS","remoteRef":{"key":"/devops-refresher/staging/app/DB_PASS"}}]'
```

## Mixing SSM and Secrets Manager

External Secrets Operator binds an `ExternalSecret` to a single `SecretStore` or `ClusterSecretStore`. If you keep non-secrets in Parameter Store and secrets in Secrets Manager, create two `ExternalSecret` resources targeting the same Secret and set `creationPolicy: Merge` so the content composes. Example:

```yaml
# external-secret-ssm.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-ssm
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: aws-parameterstore
  target:
    name: demo-app-env
    creationPolicy: Merge
  dataFrom:
    - extract:
        key: /devops-refresher/staging/app
---
# external-secret-sm.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-sm
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: aws-secretsmanager
  target:
    name: demo-app-env
    creationPolicy: Merge
  data:
    - secretKey: DB_PASS
      remoteRef:
        key: /devops-refresher/staging/app/DB_PASS
```

Apply both; the Deployment continues to `envFrom` the single Secret `demo-app-env`.

## IRSA

Annotate the ServiceAccount via values if your app needs IRSA (CSI driver or direct AWS access). Not required for ESO mode:

```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/your-irsa-role
```

## Notes

- The chart does not create a ClusterSecretStore; manage it once per cluster. Sample manifests:
  - `aws-labs/kubernetes/manifests/externalsecrets-clustersecretstore-parameterstore.yml`
  - `aws-labs/kubernetes/manifests/externalsecrets-clustersecretstore-secretsmanager.yml`
- To provision the ESO IRSA role/policy in a lab flow, see: `aws-labs/19-eks-external-secrets/README.md`.
- If you prefer file mounts, use Secrets Store CSI Driver and sync to a Secret, then `envFrom` that Secret in `templates/deployment.yaml` (similar pattern).
