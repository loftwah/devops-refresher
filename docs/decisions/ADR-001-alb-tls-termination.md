# ADR-001: ALB TLS Termination, Redirects, and DNS

## Context

- The app is exposed via an AWS Application Load Balancer (ALB) to the internet.
- We own `aws.deanlofts.xyz` in Route 53 and want HTTPS for `app.aws.deanlofts.xyz`.
- The app runs in ECS (and possibly EKS) on port 3000.

## Decision

- Terminate TLS at the ALB using an ACM certificate validated via Route 53 DNS.
- Listen on 80 and redirect HTTP → HTTPS (301) at the ALB.
- Forward HTTP (port 3000) traffic from ALB target group to ECS/EKS tasks/pods.

## Rationale

- Simpler ops: centralize TLS at ALB; ACM auto‑renews certificates.
- Least moving parts for app containers (no in‑container cert management).
- Works equally for ECS and EKS behind the same ALB.

## Considerations

- Security Groups:
  - ALB SG allows 80/443 from the internet. App SG only allows app port from ALB SG.
- TLS Policy:
  - Default `ELBSecurityPolicy-2016-08` is acceptable; tighten if compliance requires.
- HSTS:
  - Consider adding `Strict-Transport-Security` headers at the app (or via ALB if using header insert).
- Health Checks:
  - Keep `/healthz` on HTTP in the target group. Do not expose sensitive info.
- DNS & Validation:
  - Use Route 53 alias for the ALB and ACM DNS validation records.
- Subject Alternative Names (SANs):
  - If the ALB serves multiple hostnames, use one ACM cert with additional SANs or a wildcard (e.g., `*.aws.deanlofts.xyz`).
  - Add host‑based listener rules to route different hosts to separate target groups.
- End‑to‑End Encryption:
  - If required, switch target group to HTTPS and manage app‑side certs (adds operational overhead).
- WAF:
  - Optionally attach AWS WAF to the ALB for L7 protections.

## Alternatives Considered

- Terminate TLS in the container (end‑to‑end HTTPS). Rejected for increased complexity.
- NLB for TLS passthrough. Rejected; we need HTTP routing and ALB features.

## Checklist

- [x] ACM certificate issued via DNS validation
- [x] HTTP → HTTPS redirect in ALB listener
- [x] Route 53 alias A record to ALB
- [x] SGs: 80/443 on ALB, app SG from ALB only

## References

- aws-labs/12-alb (Terraform)
- aws-labs/07-security-groups (Terraform)
