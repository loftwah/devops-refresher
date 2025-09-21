# Lab 22 – Fault Lab: EKS 503 (ALB) caused by app CrashLoopBackOff

## Objectives

- Diagnose an HTTP 503/502 from an EKS-hosted app behind an ALB.
- Identify root cause with kubectl, Helm, app logs, and Terraform state.
- Apply a fix via Terraform/Helm and verify recovery.
- Capture a repeatable troubleshooting playbook.

## Scenario

Symptom observed:

- `curl -v https://demo-node-app-eks.aws.deanlofts.xyz/` → initially `HTTP/2 503`, later `HTTP/2 502` from `awselb/2.0`.

Context:

- EKS cluster and ALB Ingress are provisioned (Labs 17–19).
- DNS resolves to the ALB, TLS cert is valid.
- App served via Helm release in namespace `demo`.

## Troubleshooting Walkthrough

1. Snapshot resources and status

```bash
kubectl -n demo get deploy,svc,ingress -o wide
kubectl -n demo get pods -o wide
```

Findings:

- Deployment was not ready, Pod in `CrashLoopBackOff`.
- Ingress pointed to the correct ALB and host.

2. Inspect the failing pod

```bash
kubectl -n demo describe pod <pod>
kubectl -n demo logs <pod> --previous | tail -n 200
```

Observed:

- Logs showed: `Failed to start server Error: Postgres not ready after retries`.
- Deployment had only minimal env vars (no `DB_HOST`, `DB_*`, `REDIS_*`).

3. Confirm Helm values applied

```bash
helm -n demo get values demo-eks --all
helm -n demo get manifest demo-eks | sed -n '/kind: Deployment/,$p'
```

Observation:

- Values lacked DB/Redis envs; app was unable to connect and exited.

4. Fix env injection in Terraform/Helm

- Updated `aws-labs/19-eks-app/main.tf` to:
  - Create a Secret `demo-node-app-env` containing `APP_ENV, PORT, S3_BUCKET, DB_HOST, DB_PORT, DB_USER, DB_NAME, DB_PASS, DB_SSL, REDIS_HOST, REDIS_PORT, REDIS_TLS`.
  - Reference the Secret via `envFrom` in the Helm release (`envSecretName`).
  - Ensure Helm release depends on the Secret to avoid race conditions.

Apply and roll out:

```bash
terraform -chdir=aws-labs/19-eks-app apply -auto-approve
kubectl -n demo rollout restart deploy/demo-eks-demo-app
kubectl -n demo rollout status deploy/demo-eks-demo-app --timeout=240s
```

5. Fix image digest (InvalidImageName)

- Passed the known good digest into the Helm release:

```bash
terraform -chdir=aws-labs/19-eks-app apply -auto-approve -var 'image_tag=sha256:1d674d9db590021350d2a402213c7a4c7a2b1725bd48ca7b0e5abc7e3b5592d0'
```

6. Allow EKS pods to reach RDS

- Added an RDS SG rule to allow ingress from the EKS cluster security group (in addition to the app SG) in `aws-labs/09-rds/main.tf`:
  - New data: `data "terraform_remote_state" "eks"` and `data "aws_eks_cluster" "this"`.
  - New rule: `aws_security_group_rule.from_cluster_sg` on port 5432 from the EKS cluster SG.

Apply:

```bash
terraform -chdir=aws-labs/09-rds apply -auto-approve
```

7. Verify pods and ingress

```bash
kubectl -n demo get pods -o wide
kubectl -n demo describe ingress demo-eks-demo-app
```

- Pod became Ready.
- Ingress backend showed the pod IP and port 3000, with healthcheck-path `/healthz` annotation.

8. Validate externally

```bash
curl -sS -D - https://demo-node-app-eks.aws.deanlofts.xyz/healthz -o /dev/null
```

- Expect: `HTTP/2 200`.
- If not immediate, give ALB target health a short time to converge.

## Root Cause

- The Helm release for the EKS app deployed without the required DB/Redis environment configuration, causing the app to fail its startup Postgres wait and crash loop. This resulted in no healthy targets for the ALB and surfaced as 503/502 at the ALB.

- A subsequent roll updated resource names; we ensured the Ingress still routed to the correct Service and port.

- RDS security group access from the EKS cluster SG was added to guarantee connectivity from pods.

## Preventive Measures

- Validate env presence before rollout:

```bash
helm -n demo get values demo-eks --all | grep -E "DB_HOST|DB_USER|DB_NAME|DB_PASS|REDIS_HOST" || echo "[WARN] Missing DB/Redis envs"
```

- Keep a single, Terraform-managed Helm release per environment to avoid drift.
- Ensure RDS SG sources include the intended path (app SG and/or cluster SG) for pod connectivity.
- Consider making the app resilient to transient DB startup by not exiting the process (but keep readiness probing strict).

## Commands Reference

- Status:

```bash
kubectl -n demo get deploy,svc,ingress,pods -o wide
helm -n demo get values demo-eks --all
helm -n demo get manifest demo-eks | less
```

- Pod inspection:

```bash
kubectl -n demo describe pod <pod>
kubectl -n demo logs <pod> --previous | tail -n 200
```

- Rollout:

```bash
kubectl -n demo rollout restart deploy/<name>
kubectl -n demo rollout status deploy/<name> --timeout=240s
```

- External check:

```bash
curl -sS -D - https://demo-node-app-eks.aws.deanlofts.xyz/healthz -o /dev/null
```

## Cleanup / Final State

- Old doc `99-fault-labs.md` removed; Fault Lab is now `22-fault-labs.md`.
- EKS app now receives DB/Redis env from Secret `demo-node-app-env`.
- RDS allows ingress from the EKS cluster SG; tighten further if desired.
- Ingress healthcheck set to `/healthz`; ALB should show healthy targets.

## Acceptance Criteria

- Able to reproduce ALB 503/502, identify CrashLoopBackOff due to missing DB env, apply fixes (Secret + SG), and verify `/healthz` returns 200 via ALB.
