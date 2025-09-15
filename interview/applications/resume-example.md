# Example Resume (DevOps/Platform) — Replace with your details

Example Candidate | Sydney, NSW | email@example.com | 04xx xxx xxx | LinkedIn | GitHub

Headline

- Platform/DevOps Engineer (AWS, Kubernetes, Terraform, CI/CD, SRE)

Summary

- Built reliable, secure delivery platforms on AWS using Terraform and Kubernetes. Implemented CI/CD to EKS, improved deployment lead time and reliability with observability and clear runbooks. Excited to help <Target Company> ship faster and safer in AU.

Core Skills

- AWS (EKS, VPC, ALB/NLB, RDS, ECR), Terraform, Helm, GitHub Actions/CodeBuild, Docker, Prometheus/Grafana, ExternalDNS, IRSA, Python/Bash

Experience (Projects from this repo)
DevOps/Platform Engineer | Project Portfolio | 2024–Present

- Provisioned EKS via Terraform modules, separating cluster/nodegroups/networking; added IRSA for fine-grained access (aws-labs/17-eks-cluster).
- Implemented ALB Ingress Controller + ExternalDNS for managed routing/TLS; codified values and policies (aws-labs/18-eks-alb-externaldns, aws-labs/kubernetes/helm/aws-load-balancer-controller-values.yml).
- Shipped CI/CD to EKS with environment gates and artifacts; documented pipeline decisions (aws-labs/20-cicd-eks-pipeline, demo-node-app/buildspec.yml, docs/decisions/ADR-007-cicd-eks-pipeline.md).
- Built observability with Prometheus/Grafana; defined service SLIs and created runbooks for incidents (aws-labs/16-observability, docs/runbooks/\*).
- Hardened networking and IAM using Terraform modules; documented ALB TLS termination and SG strategy (aws-labs/07-security-groups, docs/decisions/ADR-001-alb-tls-termination.md, docs/security-groups.md).
- Containerised app with multi-stage Docker build; created Helm chart and manifests for deployment (demo-node-app/Dockerfile, demo-node-app/deploy/eks/chart/).

Selected Labs

- VPC + Endpoints, ECR, RDS, ECS → EKS evolution (aws-labs/01-vpc, 02-vpc-endpoints, 03-ecr, 09-rds, 14-ecs-service, 17-eks-cluster).
- Secrets and config: External Secrets/CSI, parameter store (aws-labs/kubernetes/manifests/\*, aws-labs/11-parameter-store.md).

Projects

- Demo Node App CI/CD to EKS with ALB + DNS — `demo-node-app/`, `aws-labs/18-eks-alb-externaldns/`, `aws-labs/20-cicd-eks-pipeline/`.

Certifications (if applicable)

- AWS SAA, CKAD

Keywords (tailor to JD)

- AWS, EKS, Kubernetes, Terraform, Helm, CI/CD, Docker, Prometheus, Grafana, ALB, ExternalDNS, IRSA, SRE, Runbooks
