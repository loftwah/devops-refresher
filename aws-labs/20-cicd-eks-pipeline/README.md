# Lab 21 – CI/CD for EKS (Helm via CodePipeline/CodeBuild)

## Objective

Create a CodePipeline that deploys the in-repo Helm chart to EKS on pushes to `main` in the app repo. Uses an inline buildspec to run `helm upgrade --install` so everything is self-contained here.

## Why a separate lab and pipeline?

- Lab 15 builds and deploys to ECS earlier in the sequence. To keep ordering strict and avoid re-numbering, this lab adds an EKS pipeline at the end (21) rather than modifying the earlier ECS pipeline.
- Both pipelines trigger from the same GitHub repo/branch. This is supported. The EKS pipeline waits for the image tag (`<git-sha>`) to appear in ECR before deploying.

## Prerequisites

- Labs 17–20 applied (EKS cluster, controllers, ESO, app chart ready).
- IAM lab (06) applied (provides CodePipeline/CodeBuild roles via remote state).
- CodeConnections GitHub connection exists (same as Lab 15).
- Cluster RBAC: map the CodeBuild role to your EKS cluster in `aws-auth` (staging shortcut uses `system:masters`). Use the helper script:

```
aws-labs/scripts/eks-map-aws-auth.sh arn:aws:iam::<acct>:role/devops-refresher-codebuild-role \
  $(cd ../17-eks-cluster && terraform output -raw cluster_name) ap-southeast-2 system:masters
```

## Apply

```
cd aws-labs/21-cicd-eks-pipeline
terraform init
terraform apply -auto-approve
```

Outputs:

- `pipeline_name`, `codebuild_project`

## How it works

- Source: CodeConnections (GitHub) `loftwah/demo-node-app@main`.
- Build (Deploy): CodeBuild installs `kubectl` and `helm`, waits for `ECR: <git-sha>` tag, discovers the image digest, then runs `helm upgrade --install` against:
  - Chart: `aws-labs/kubernetes/helm/demo-app`
  - Values: `aws-labs/kubernetes/helm/demo-app/values-eks-staging-app.yaml`
  - Sets `image.repository`, `image.tag` (commit short SHA), `image.digest` (immutable), `image.pullPolicy=Always`, `buildVersion=<git-sha>`, and `ingress.certificateArn` (from Lab 18).
  - Uses `--wait --atomic` to block until rollout completes or fail clearly.

### Why these flags matter (lessons learned)

- Kubernetes only rolls when the pod template changes. Reusing a mutable tag like `staging` with `IfNotPresent` can silently skip updates.
- We set `buildVersion` (a pod-template annotation) on every deploy to force a new ReplicaSet even if a human accidentally uses a mutable tag.
- We pass the immutable `image.digest` so the container reference always changes and exactly matches the built image.
- We set `image.pullPolicy=Always` in EKS staging values to ensure nodes pull the image on restart.

### Platform detection in the app

- The app auto-detects Kubernetes/EKS and updates the homepage banner.
- Explicit override via `DEPLOY_PLATFORM` (also accepts `RUN_PLATFORM` or `PLATFORM`) takes precedence.
- This lab’s Helm values set `env` to inject `DEPLOY_PLATFORM=eks` by default.

## Notes

- Single vs dual pipelines: We prefer a single pipeline that builds once and deploys to both ECS and EKS, but to preserve lab ordering and avoid breaking earlier content, this lab introduces a second pipeline focused on EKS deploy. Future improvement: unify into one.
- Same repo/branch triggers: Both pipelines will start on each push. The EKS deploy waits for the ECR tag to appear and reads the digest to avoid a race and ensure immutability.
- Inline buildspec: Kept in Terraform (inline) for easier reference in this repo, mirroring the style used in earlier labs.

## Manual Deploy Script

For ad-hoc deploys that mirror the pipeline behavior, use the helper script with your lab profile/region:

```
PROFILE=devops-sandbox AWS_REGION=ap-southeast-2 \
  ./aws-labs/scripts/eks-deploy-app.sh
```

Options:

- `IMAGE_TAG` or `IMAGE_DIGEST` to pin the image (digest preferred)
- `NAMESPACE`, `RELEASE_NAME` to target a different release
- `CLUSTER_NAME` to override discovery from Lab 17 outputs
- Uses cluster name from Lab 17 outputs by default; ensure that state exists
