# Application Load Balancer

## Objectives

- Provide external HTTPS entry for the backend API.
- ECS: Provision ALB + TG in Terraform and attach the ECS service.
- EKS: Use AWS Load Balancer Controller with Ingress to create ALB dynamically.

## ECS Path (Terraform-managed ALB)

### Tasks

1. Create ALB across public subnets with a dedicated SG allowing 80/443.
2. Create a target group (HTTP, port 80) with health check path matching your app (e.g., `/health`).
3. Create listeners: 80 → redirect 443; 443 → forward to TG (attach ACM cert).
4. Attach ECS service to the target group; ensure service SG allows traffic from ALB SG.

### Acceptance Criteria

- ALB DNS shows 301 on http and valid TLS on https.
- Target group health is healthy after ECS service is attached.

### Hints

- Use Route53 alias for a friendly name.
- Health check path must match the app and return 200.

## EKS Path (Ingress-managed ALB)

### Prerequisites

- AWS Load Balancer Controller installed on the cluster with IRSA and the recommended IAM policy.
- Optionally ExternalDNS for Route53 records.

### Tasks

1. Annotate a Kubernetes Ingress with ALB schema and TLS settings.
2. Reference an ACM cert via `alb.ingress.kubernetes.io/certificate-arn`.
3. Controller provisions ALB, listeners, and target group bound to your Service.

Example Ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api
  namespace: app
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:<region>:<acct>:certificate/<id>
    alb.ingress.kubernetes.io/ssl-redirect: "443"
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 80
```

### Acceptance Criteria

- Ingress creates an ALB with healthy targets pointing to your Service.
- HTTPS works with the specified ACM certificate.

### Hints

- Ensure Service type is `NodePort` or ClusterIP (controller handles target registration).
- Use `alb.ingress.kubernetes.io/healthcheck-path` if your path differs from `/`.
