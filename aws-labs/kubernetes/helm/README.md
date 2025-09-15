# kubernetes/helm

This directory contains Helm values files for Kubernetes controllers used in the labs. You pass these files to `helm upgrade --install` with `-f` to keep installs reproducible and readable.

## Files

- aws-load-balancer-controller-values.yml
  - What: Values for the AWS Load Balancer Controller Helm chart.
  - When: You want Kubernetes Ingress to provision/manage AWS ALBs for HTTP/HTTPS traffic.
  - Where: Install into the `kube-system` namespace on your EKS cluster.
  - How: Provides `clusterName` and creates an IRSA-annotated ServiceAccount so the controller can call AWS APIs via an IAM role.
  - Why: ALB Ingress integrates cleanly with EKS, supports path/host routing, TLS, WAF, and saves hand-rolling ELB config.
  - Real-world example: A multi-service API where `/api/*` routes to `web` and `/admin/*` to `admin` behind a single ALB; certs via ACM; DNS via Route 53.
  - Usage:
    ```bash
    helm repo add eks https://aws.github.io/eks-charts
    helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
      -n kube-system -f aws-labs/kubernetes/helm/aws-load-balancer-controller-values.yml
    # Verify
    kubectl -n kube-system get deploy aws-load-balancer-controller
    kubectl -n kube-system logs deploy/aws-load-balancer-controller | tail -n 50
    ```

- secrets-store-csi-driver-values.yml
  - What: Values for the Secrets Store CSI Driver Helm chart.
  - When: You want to mount secrets/config from AWS Secrets Manager or SSM into Kubernetes as files and/or synced Secrets.
  - Where: Install into the `kube-system` namespace; pair with the AWS provider.
  - How: Enables Linux driver, secret rotation, and syncing to native Kubernetes Secrets (so you can `envFrom` them).
  - Why: Centralises secret management in AWS, avoids duplicating secrets in Git or static Kubernetes manifests.
  - Real-world example: Backend pods consume `DB_PASS` from Secrets Manager and non-secrets from SSM, surfaced into an app Secret via Secrets Store; Deployments use `envFrom` that Secret.
  - Usage:
    ```bash
    helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
    helm upgrade --install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
      -n kube-system -f aws-labs/kubernetes/helm/secrets-store-csi-driver-values.yml
    # Verify
    kubectl -n kube-system get ds -l app=secrets-store-csi-driver
    kubectl -n kube-system logs ds/csi-secrets-store-secrets-store-csi-driver | tail -n 50
    ```

## Placeholders / Variables

- `${CLUSTER_NAME}`, `${ALB_ROLE_ARN}`: Substitute these before running Helm (shell env expansion if your tooling supports it, or pre-render the file).

## Why `.yml`?

- Kubernetes and Helm accept both `.yml` and `.yaml`. This repo uses `.yml` consistently (except Helm’s `Chart.yaml` defaults) to align with common tools like Docker Compose.
