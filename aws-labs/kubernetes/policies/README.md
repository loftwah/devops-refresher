# kubernetes/policies

IAM policies used by Kubernetes controllers in the labs. We keep copies here so Terraform can reference them with `file(...)` and to make changes auditable in Git.

## Files

- aws-load-balancer-controller.json
  - What: Recommended IAM policy for the AWS Load Balancer Controller.
  - When: Required before installing the controller with IRSA so it can create/modify ALBs, listeners, target groups, and related resources.
  - Where: Attached to the IRSA role assumed by `kube-system:aws-load-balancer-controller`.
  - How: Terraform reads this JSON with `file(...)` and attaches it to the role.
  - Why: Without these permissions, the controller can’t reconcile Ingress to AWS resources; you’d see errors in controller logs and no ALB would appear.
  - Real-world example: Product team defines multiple Ingress objects; controller synthesizes a single ALB with host/path rules, ACM certs, and WAF association.
  - Terraform reference:
    ```hcl
    resource "aws_iam_policy" "alb" {
      name   = "AWSLoadBalancerControllerPolicy"
      policy = file("kubernetes/policies/aws-load-balancer-controller.json")
    }
    ```
  - Upstream source (refresh on upgrades):
    https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/main/docs/install/iam_policy.json

## Versioning

- Controller versions may add permissions. When upgrading the Helm chart, refresh this JSON from upstream and include the version in your commit message.

## Verification

- After install, create a simple Ingress. Verify in controller logs that it creates an ALB and target group; confirm in AWS console (`EC2 → Load Balancers`).
- Failure modes: `AccessDenied` in logs for `elasticloadbalancing:*` or `ec2:*` actions indicates missing or outdated permissions; update the policy file accordingly.
