# kubernetes/manifests

This directory holds raw Kubernetes manifests that are not managed by Helm charts, typically one-off patches or CRDs from upstream projects.

## Files

- secrets-store-csi-driver-provider-aws-sa-patch.yml
  - What: Patches the ServiceAccount `secrets-store-csi-driver-provider-aws` in `kube-system` to include the IRSA role annotation.
  - When: After installing the AWS provider manifests for the Secrets Store CSI Driver.
  - Where: Namespace `kube-system`, ServiceAccount owned by the provider installer.
  - How: Apply the upstream installer, then pipe this patch through `envsubst` to inject your `${SSCSID_ROLE_ARN}` and apply.
  - Why: Without IRSA, the provider cannot call AWS APIs to read from Secrets Manager or SSM, and secret mounts will fail.
  - Real-world example: Your app depends on `DB_PASS` from Secrets Manager and `APP_ENV` from SSM. The provider reads those and presents them to pods via Secrets Store.
  - Commands:
    ```bash
    kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml
    export SSCSID_ROLE_ARN=arn:aws:iam::<acct-id>:role/eks-secrets-store-aws-provider
    envsubst < kubernetes/manifests/secrets-store-csi-driver-provider-aws-sa-patch.yml | kubectl -n kube-system apply -f -
    # Verify
    kubectl -n kube-system get sa secrets-store-csi-driver-provider-aws -o yaml | rg eks.amazonaws.com/role-arn
    ```

## When to use manifests vs Helm

- Use Helm when a project publishes a chart or you maintain one — it simplifies upgrades and drift management.
- Use manifests for vendor-provided static resources or quick patches. The labs show both approaches so you can compare trade-offs.
