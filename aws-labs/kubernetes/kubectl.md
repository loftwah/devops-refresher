# Kubernetes – Minimal Cheatsheet (EKS)

Commands are explicit — no env vars required.

Cluster access

- Update kubeconfig: `aws eks update-kubeconfig --profile devops-sandbox --region ap-southeast-2 --name devops-refresher-staging`
- Current context: `kubectl config current-context`

App namespace (demo)

- Overview: `kubectl -n demo get deploy,rs,pods,svc,ingress -o wide`
- Rollout: `kubectl -n demo rollout status deploy/demo-demo-app --timeout=5m`
- Logs: `kubectl -n demo logs deploy/demo-demo-app --all-containers --tail=200`
- Events: `kubectl -n demo get events --sort-by=.lastTimestamp | tail -n 50`
- Describe pod: `P=$(kubectl -n demo get pods -o jsonpath='{.items[0].metadata.name}'); kubectl -n demo describe pod "$P"`

Ingress / ALB

- Ingress: `kubectl -n demo get ingress -o wide && kubectl -n demo describe ingress demo-demo-app`
- LBC logs: `kubectl -n kube-system logs deploy/aws-load-balancer-controller --tail=200 | grep -Ei 'demo|ingress|error|warn' || true`

Common symptoms

- ImagePullBackOff: node group can’t pull the image. Lab 17 attaches `AmazonEC2ContainerRegistryReadOnly` to the node role; roll nodes if they predate the policy.
- Ingress Pending: ALB not provisioning. Ensure Lab 18 applied and LBC is Ready (`kubectl -n kube-system get deploy aws-load-balancer-controller`).

Clean up (app only)

- Remove app via Terraform: `terraform -chdir=aws-labs/20-eks-app destroy --auto-approve`
