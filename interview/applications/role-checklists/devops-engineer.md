# DevOps Engineer Checklist (AU DevOps)

Core Signals

- CI/CD pipelines (build, test, scan, deploy), artifacts, environments
- Docker images, multi-stage builds, deploy to ECS/EKS
- Secrets and config management; validations and policy
- Developer enablement: templates, pre-commit, docs, ADRs

Portfolio Evidence From This Repo

- App CI/CD and Docker: `demo-node-app/Dockerfile`, `demo-node-app/buildspec.yml`, `docs/slack-cicd-integration.md`
- CI to EKS/ECS: `aws-labs/20-cicd-eks-pipeline/`, `aws-labs/15-cicd-ecs-pipeline.md`
- Validation strategy + flags: `docs/validation-strategy.md`, `docs/terraform-flags.md`
- Secrets/config: `docs/build-vs-runtime-config.md`, `aws-labs/kubernetes/manifests/*secrets*`, `kubernetes/helm/demo-app/templates/externalsecret.yaml`
- Decision records: `docs/decisions/*.md`

Interview Prep Focus

- Pipeline design: caching, fan-out/fan-in, approvals, rollback triggers
- Supply chain security: base images, SBOM, scans, provenance (discuss approach)
- Environment strategies: feature flags, previews, prod promotion
- Developer ergonomics: templates, docs, fast feedback

ATS Keywords

- CI/CD, GitHub Actions/CodeBuild, Docker, EKS/ECS, Terraform, Helm, Trunk-based, Canary, Blue/Green, Secrets, SBOM, Scanning
