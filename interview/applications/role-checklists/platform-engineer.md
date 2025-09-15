# Platform Engineer Checklist (AU DevOps)

Core Signals

- Kubernetes platform ownership (multi-tenant EKS), paved paths, golden templates
- IaC modules (Terraform), policy-as-code (OPA/Gatekeeper), IRSA
- CI/CD for apps and infra, artifact mgmt, deployments (blue/green, canary)
- Observability (Prometheus/Grafana), SLOs for platform services, runbooks
- Secrets management (External Secrets / CSI driver), networking (ALB/ingress)

Portfolio Evidence From This Repo

- EKS cluster with Terraform: `aws-labs/17-eks-cluster/`
- ALB + ExternalDNS on EKS: `aws-labs/18-eks-alb-externaldns/`
- Helm chart for app: `aws-labs/kubernetes/helm/demo-app/` and `demo-node-app/deploy/eks/chart/`
- CI/CD to EKS: `aws-labs/20-cicd-eks-pipeline/`, `demo-node-app/buildspec.yml`, `docs/decisions/ADR-007-cicd-eks-pipeline.md`
- Policies & controllers: `aws-labs/kubernetes/policies/`, `aws-labs/kubernetes/helm/aws-load-balancer-controller-values.yml`
- Observability stack: `aws-labs/16-observability/`, `docs/eks-overview.md`

Interview Prep Focus

- Multi-tenant isolation, quotas, namespaces, IRSA, network policies
- Rollout strategies on ALB/EKS; failure modes and rollback plans
- Module boundaries: cluster, node groups, ingress, DNS; upgrade strategy
- Cost controls: right-sizing nodes, spot, artifact and metrics retention

ATS Keywords

- AWS, EKS, Kubernetes, Terraform, Helm, OPA/Gatekeeper, IRSA, ALB, ExternalDNS, CI/CD, Prometheus, Grafana, SLOs, Runbooks
