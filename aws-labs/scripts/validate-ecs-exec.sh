#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE="${AWS_PROFILE:-devops-sandbox}"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-ap-southeast-2}}"
CLUSTER="devops-refresher-staging"
SERVICE="app"

info() { printf "[INFO] %s\n" "$*"; }
ok()   { printf "[ OK ] %s\n" "$*"; }
err()  { printf "[FAIL] %s\n" "$*"; }
aws_cli() { aws ${PROFILE:+--profile "$PROFILE"} ${REGION:+--region "$REGION"} "$@"; }

fail=0

info "Validating ECS Exec prerequisites"

# 1) Service has Exec enabled
enabled=$(aws_cli ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" \
  --query 'services[0].enableExecuteCommand' --output text 2>/dev/null || echo "False")
if [[ "$enabled" != "True" ]]; then err "ECS Exec not enabled on service $SERVICE"; fail=1; else ok "ECS Exec enabled on service"; fi

# 2) Roles have AmazonSSMManagedInstanceCore
LABS_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)
IAM_DIR="$LABS_DIR/06-iam"
VPC_DIR="$LABS_DIR/01-vpc"
exec_role=$(terraform -chdir="$IAM_DIR" output -raw execution_role_arn 2>/dev/null || echo "")
task_role=$(terraform -chdir="$IAM_DIR" output -raw task_role_arn 2>/dev/null || echo "")

check_policy_attached() {
  local role_arn="$1"; local name; name=$(basename "$role_arn")
  [[ -n "$name" ]] || { err "Missing role for check"; fail=1; return; }
  attached=$(aws_cli iam list-attached-role-policies --role-name "$name" \
    --query 'AttachedPolicies[?PolicyArn==`arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore`]' --output text || true)
  if [[ -z "$attached" ]]; then err "Role $name missing AmazonSSMManagedInstanceCore"; fail=1; else ok "Role $name has AmazonSSMManagedInstanceCore"; fi
}

check_policy_attached "$exec_role"
check_policy_attached "$task_role"

# 3) VPC endpoints (SSM trio) exist (structure-only check)
# Read from Lab 01 state
if ! vpc_id=$(terraform -chdir="$VPC_DIR" output -raw vpc_id 2>/dev/null); then
  err "Could not determine VPC ID from Lab 01 outputs"; fail=1
else
  for svc in ssm ssmmessages ec2messages; do
    cnt=$(aws_cli ec2 describe-vpc-endpoints --filters \
      Name=vpc-id,Values="$vpc_id" Name=service-name,Values="com.amazonaws.${REGION}.${svc}" \
      --query 'length(VpcEndpoints)' --output text 2>/dev/null || echo 0)
    if [[ "$cnt" -lt 1 ]]; then err "Missing interface endpoint: $svc"; fail=1; else ok "Endpoint present: $svc"; fi
  done
fi

if [[ "$fail" -eq 0 ]]; then ok "ECS Exec validation passed"; else err "ECS Exec validation failed"; exit 1; fi

