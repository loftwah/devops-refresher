# Rotate APP_AUTH_SECRET

Goal: Safely rotate the application authentication secret stored in AWS Secrets Manager and consumed by ECS tasks as env `APP_AUTH_SECRET`.

## Preconditions

- Secret name: `/devops-refresher/<env>/app/APP_AUTH_SECRET` (string value)
- ECS tasks reference Secrets Manager by ARN via task definition `secrets` (auto-loaded by Lab 14 when key present).
- Rotation is coordinated with any dependent services that verify or decode tokens signed/encrypted with the secret.

## Option A — Manual Rotation (Recommended for app secrets)

1. Plan compatibility window (if your tokens are long-lived):
   - If feasible, support verifying tokens with both the new and previous secret for a short period.
   - Shorten token TTL ahead of rotation if dual-validation is not available.

2. Generate a new strong secret:
   - 32+ random bytes, base64 or hex. For example:
     - `openssl rand -base64 32`

3. Update Secrets Manager:
   - Put the new value to `/devops-refresher/<env>/app/APP_AUTH_SECRET`.
   - You can do this via:
     - Terraform (Parameter Store lab):
       - `cd aws-labs/11-parameter-store`
       - `terraform apply -var 'secret_values={ APP_AUTH_SECRET="<new-secret>" }' -auto-approve`
     - or AWS Console / CLI:
       - `aws secretsmanager put-secret-value --secret-id /devops-refresher/<env>/app/APP_AUTH_SECRET --secret-string '<new-secret>' --profile devops-sandbox --region ap-southeast-2`

4. Restart workloads to pick up the new value:
   - ECS: `terraform apply` in `aws-labs/14-ecs-service` or trigger a new deployment; this forces tasks to restart with the latest secret value.

5. Validate:
   - Use `scripts/print-ssm-params.sh /devops-refresher/<env>/app` to confirm the secret exists (set `MASK_SECRETS=1` to mask output).
   - Check the app’s `/healthz` and auth flows.

6. Clean up compatibility window:
   - If you temporarily validated with both secrets, remove the old secret from app config after traffic is stable.

## Option B — Versioned Rotation with Stages (Advanced)

- You may maintain two secrets (e.g., `APP_AUTH_SECRET_CURRENT` and `APP_AUTH_SECRET_PREVIOUS`) or use the same secret with application-level support for multiple versions. ECS itself does not consume Secrets Manager stages; it always resolves the latest `SecretString`.

## Notes

- Downtime: Not required if you roll deployments and handle token verification properly.
- Audit: Changes to the secret are logged in CloudTrail and Secrets Manager audit history.
- IAM: Execution role must allow `secretsmanager:GetSecretValue` on `/devops-refresher/<env>/app/*` (Lab 06 covers this).

## References

- Lab 11 Parameter Store: manages creation of Secrets Manager entries alongside SSM params.
- Lab 14 ECS Service: default `secret_keys` covers DB_PASS; add `APP_AUTH_SECRET` via `-var 'secret_keys=["DB_PASS","APP_AUTH_SECRET"]'` or update default as needed.
- DB password rotation: `docs/runbooks/rotate-db-password.md` (similar rollout/redeploy pattern).
