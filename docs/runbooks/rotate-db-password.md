# Rotate DB Password (PostgreSQL on RDS)

Goal: Safely rotate the application database user password stored in AWS Secrets Manager and consumed by ECS tasks.

Preconditions
- Secret name: `/devops-refresher/<env>/app/DB_PASS` (string value)
- App reads DB creds from env: `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_NAME`, `DB_SSL`, and `DB_PASS` from Secrets Manager.
- ECS tasks reference Secrets Manager by ARN under `container_definitions.secrets`.

Option A — Managed Rotation (Recommended)
- Use Secrets Manager’s built‑in rotation for RDS PostgreSQL.
- Steps:
  - Create or update a Secrets Manager secret of type “Credentials for RDS database”.
  - Attach to the RDS instance/cluster and enable rotation (e.g., 30 days) with the “Rotate single user” template.
  - Secrets Manager stores versions with stages `AWSCURRENT` and `AWSPREVIOUS` and updates the DB password atomically.
  - ECS impact: containers that load `DB_PASS` at startup won’t see the new value until they restart. Plan a rolling deployment after rotation windows.

Option B — Manual Rotation Runbook
1) Generate a new strong password.
2) Update RDS user password:
   - Temporarily allow your IP on the RDS SG (if needed) or exec into a maintenance task with psql access.
   - ALTER USER:
     - `ALTER USER <app_user> WITH PASSWORD '<new_password>';`
3) Update Secrets Manager:
   - Put new secret value on `/devops-refresher/<env>/app/DB_PASS` (overwrites the SecretString).
4) Redeploy ECS service:
   - New tasks will fetch `DB_PASS` at start; do a rolling restart to pick up the change.
5) Verify:
   - Health checks green; app connects with new password; CloudWatch logs clean.
6) Cleanup:
   - Ensure no consumers still rely on the old password; if you created a temporary ingress rule, remove it.

Notes
- Live reload: Environment variables are fixed at container start. If you need immediate adoption without restart, fetch the secret at runtime with the AWS SDK and cache for a short TTL.
- Dual password window: PostgreSQL doesn’t support two active passwords for one role; use the AWSPREVIOUS stage with managed rotation if you need a grace period.
- Access control: The ECS task role already has permission to read `/devops-refresher/<env>/app/DB_PASS`.

