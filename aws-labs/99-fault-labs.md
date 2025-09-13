# Fault Labs (Troubleshooting on ECS and EKS)

## Objectives

- Reproduce realistic failure modes and practice detection, root cause analysis, resolution, and mitigation on ECS/EKS.
- Understand how the platforms react automatically (restarts, replacements, rollbacks) and when human action is required.

## Ground Rules

- Keep changes scoped to staging/non‑prod. Revert any temporary breakages at the end of each exercise.
- Have two shells ready: one for breaking things, one for observing (logs, health, metrics).

## Scenario 1: Health Check Tool Missing In Image

Why this happens

- Minimal images (e.g., `alpine`, distroless) often lack `curl`, `wget`, or `nc`. If the container healthCheck/Probe uses one of these tools, it fails with exit 127 (command not found).

How to introduce

- ECS: set a container health check that uses curl on an image without curl:
  - Task definition excerpt: `healthCheck: { command: ["CMD-SHELL", "curl -fsS http://localhost:3000/health || exit 1"], interval: 10, retries: 3 }`
  - Deploy using an image that lacks curl (e.g., `node:lts-alpine` without installing curl).
- EKS: set a liveness/readiness probe using `exec` and curl:
  - Probe example: `exec: ["/bin/sh", "-c", "curl -fsS localhost:3000/health"]`
  - Use an image that doesn’t include curl.

What you’ll see

- ECS: `aws ecs describe-tasks` shows container health `UNHEALTHY`; service replaces tasks repeatedly. ALB target health flips to unhealthy; 5xx increase if all targets fail.
- EKS: Pod restarts; `kubectl describe pod` shows probe failures with exit code 127; readiness=false so traffic not routed.

How to resolve

- Prefer probe types that don’t require tools:
  - ECS: ALB target group HTTP health check to a path (`/health`); remove container CMD health check that shells out to curl.
  - EKS: use `httpGet` probe instead of `exec`:
    - `readinessProbe: { httpGet: { path: /health, port: 3000 } }`
- If you must use `exec`, bake the tool in the image:
  - Alpine Dockerfile: `RUN apk add --no-cache curl`
  - Debian/Ubuntu: `RUN apt-get update && apt-get install -y --no-install-recommends curl`
- Add an app‑native health endpoint that returns 200 quickly and does not touch external dependencies.

Mitigations

- Enforce `httpGet` probes in K8s via policy; lint task defs to avoid shell health checks.
- Use multi‑stage builds that add only what’s needed for runtime health checks.
- Canary deploys and alarms on `TargetGroupUnhealthyHostCount` catch issues quickly.

Platform behavior

- ECS: When container health check fails, the service scheduler stops the task and launches a replacement. With deployment circuit breaker enabled, a failing deployment can auto‑rollback. ALB deregisters unhealthy targets and stops routing to them.
- EKS: Kubelet restarts containers failing liveness; readiness gates prevent traffic until healthy. ReplicaSet maintains desired count.

## Scenario 2: Wrong Health Check Path/Port

How to introduce

- ALB Target Group health check points to `/ready` but app serves `/health`; or target group uses port 80 while container listens on 3000.

Observation

- Target shows `unhealthy` with reason `Health checks failed with these codes: [404]` or timeout. ECS service events mention deregistration; app logs show no incoming requests.

Resolution

- Align container port and target group port; ensure the container definition exposes the same port mapped by the service.
- Fix path to the correct endpoint and lower thresholds (`healthyThreshold=2`, `timeout=5s`) during troubleshooting.

Mitigations

- Keep `/health` and `/ready` consistent across services; codify via module defaults.
- Add synthetic checks (Route 53 health checks or CloudWatch Synthetics) against the public URL.

## Scenario 3: Network Egress Blocked (SG/NACL/VPC Endpoints)

How to introduce

- Remove 0.0.0.0/0 egress from the app security group; or tighten NACL to block ephemeral ports; or remove NAT gateway in private subnets; or disable needed VPC interface endpoints (e.g., `ssm`, `ecr.api`, `ecr.dkr`).

Observation

- App cannot reach external APIs, SSM, ECR. Startup pulls/sts calls time out. Logs show DNS resolves but TCP fails, or SDK timeouts to AWS endpoints.
- ECS task provisioning may fail to pull image if ECR endpoints are missing and there’s no internet path.

Resolution

- Restore SG egress to 0.0.0.0/0 for app tasks (or to specific CIDRs as policy allows).
- Ensure NAT gateway route for private subnets or re‑enable required VPC interface endpoints with Private DNS.
- For ECR: ensure `ecr.api`, `ecr.dkr` endpoints (or internet egress) and execution role has ECR permissions.

Mitigations

- Validate baseline endpoints with a script (see `aws-labs/scripts/validate-vpc-endpoints.sh`).
- Use Reachability Analyzer and automated checks in CI to detect missing routes/endpoints.

## Scenario 4: DNS Failures (Resolver/Records/Changes)

How to introduce

- Change Route 53 record to a wrong target, or delete it; set an extremely long TTL; or misconfigure the cluster DNS in a pod.

Observation

- `getaddrinfo ENOTFOUND` or `NameResolutionError` in logs. `nslookup` inside the container fails or returns stale results. ALB points to wrong service.

Resolution

- Fix the Route 53 record target and appropriate TTL (e.g., 60s). For K8s internal DNS, ensure CoreDNS pods are healthy and the pod `dnsPolicy` is default/cluster‑first.

Mitigations

- Use ExternalDNS with RBAC‑scoped changes and Git‑managed records; alarm on DNS health via synthetic checks.

## Scenario 5: IAM Denied (SSM/Secrets/S3/ECR)

How to introduce

- Remove `ssm:GetParameters*` or `secretsmanager:GetSecretValue` from task role; or trim S3 bucket access; or over‑restrict CodePipeline/CodeBuild roles.

Observation

- Errors like `AccessDeniedException` in app or pipeline logs. On ECS/EKS, app fails loading config; on deploy, CodePipeline cannot `iam:PassRole` or `ecs:UpdateService`.

Resolution

- Restore least‑privilege policies:
  - App task/IRSA: allow `ssm:GetParameter*` on the exact param path and `secretsmanager:GetSecretValue` on specific secret ARNs; add `kms:Decrypt` if using CMKs.
  - S3: scope to bucket and path prefixes in use.
  - CodePipeline/CodeBuild: allow `ecs:*` subset needed (or temporarily broader during break‑glass), `iam:PassRole` for task and execution roles, and `codestar-connections:UseConnection` for the configured connection.

Mitigations

- Keep IAM as code; add policy tests/linters; ship tailored managed policies per role. Add CloudWatch alarms on common `AccessDenied` patterns.

## How To Observe Quickly

- ECS:
  - `aws ecs describe-services --cluster <cluster> --services <svc>`
  - `aws ecs list-tasks --cluster <cluster> --service <svc>` then `aws ecs describe-tasks ...`
  - `aws logs tail /aws/ecs/<svc> --follow`
  - `aws ecs execute-command --command "sh" ...` to test curl/DNS from inside.
- EKS:
  - `kubectl get pods -n <ns>`; `kubectl describe pod <pod> -n <ns>`
  - `kubectl logs <pod> -c <container> -n <ns> --previous` for restarts
  - `kubectl exec -it <pod> -n <ns> -- sh` and test connectivity
- ALB/TG:
  - Target health reasons; `HTTPCode_Target_5XX_Count`, `UnHealthyHostCount` metrics.

## Cleanup

- Revert any SG/NACL/Route 53/role changes. Restore healthy probes and redeploy the working image.

## Acceptance Criteria

- You can cause and resolve each failure. You can explain why it occurred, how the platform reacted automatically, and what guardrails mitigate recurrence.
