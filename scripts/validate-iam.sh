#!/usr/bin/env bash
set -Eeuo pipefail

# Validates IAM roles created in aws-labs/06-iam
# - Existence of execution and task roles
# - Trust policy principal = ecs-tasks.amazonaws.com
# - Execution role has AmazonECSTaskExecutionRolePolicy attached
# - Optional extra policies (SSM/Secrets/KMS) are reported if present

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)
IAM_DIR="$ROOT_DIR/aws-labs/06-iam"

# Basic colored output (respects NO_COLOR and non-TTY)
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET="\033[0m"; C_INFO="\033[36m"; C_OK="\033[32m"; C_FAIL="\033[31m"
else
  C_RESET=""; C_INFO=""; C_OK=""; C_FAIL=""
fi
info() { printf "${C_INFO}[INFO]${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_OK}[ OK ]${C_RESET} %s\n" "$*"; }
err()  { printf "${C_FAIL}[FAIL]${C_RESET} %s\n" "$*"; }

require() { command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found"; exit 1; }; }

AWS_PROFILE_EFFECTIVE="${AWS_PROFILE:-}"
AWS_REGION_EFFECTIVE="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
ROLE_EXEC_NAME="devops-refresher-staging-ecs-execution"
ROLE_TASK_NAME="devops-refresher-staging-app-task"

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--profile) AWS_PROFILE_EFFECTIVE="$2"; shift 2 ;;
      -r|--region)  AWS_REGION_EFFECTIVE="$2"; shift 2 ;;
      --exec-role)  ROLE_EXEC_NAME="$2"; shift 2 ;;
      --task-role)  ROLE_TASK_NAME="$2"; shift 2 ;;
      -h|--help)
        cat <<EOF
Usage: $(basename "$0") [options]
  -p, --profile NAME   AWS profile
  -r, --region  NAME   AWS region
      --exec-role NAME Execution role name (default: $ROLE_EXEC_NAME)
      --task-role NAME Task role name (default: $ROLE_TASK_NAME)
EOF
        exit 0 ;;
      *) err "Unknown argument: $1"; exit 2 ;;
    esac
  done
}

aws_cli() {
  local region_flag=( ) profile_flag=( )
  [[ -n "${AWS_REGION_EFFECTIVE:-}" ]] && region_flag=(--region "$AWS_REGION_EFFECTIVE")
  [[ -n "${AWS_PROFILE_EFFECTIVE:-}" ]] && profile_flag=(--profile "$AWS_PROFILE_EFFECTIVE")
  aws "${profile_flag[@]}" "${region_flag[@]}" "$@"
}

discover_defaults() {
  # Default profile/region from providers.tf if unset
  if [[ -z "${AWS_PROFILE_EFFECTIVE:-}" && -f "$IAM_DIR/providers.tf" ]]; then
    AWS_PROFILE_EFFECTIVE=$(awk '/variable "aws_profile"/,/}/ { if ($1=="default") { gsub(/"/, "", $3); print $3 } }' "$IAM_DIR/providers.tf" || true)
  fi
  if [[ -z "${AWS_REGION_EFFECTIVE:-}" && -f "$IAM_DIR/providers.tf" ]]; then
    AWS_REGION_EFFECTIVE=$(awk '/variable "region"/,/}/ { if ($1=="default") { gsub(/"/, "", $3); print $3 } }' "$IAM_DIR/providers.tf" || true)
  fi
  # If Terraform outputs exist, prefer discovered names/ARNs
  if command -v terraform >/dev/null 2>&1; then
    if terraform -chdir="$IAM_DIR" init -input=false >/dev/null 2>&1; then
      local tf_json
      tf_json=$(terraform -chdir="$IAM_DIR" output -json 2>/dev/null || echo '{}')
      local task_role_name_out exec_role_arn_out
      task_role_name_out=$(jq -r '.task_role_name.value' <<<"$tf_json" 2>/dev/null || echo "")
      exec_role_arn_out=$(jq -r '.execution_role_arn.value' <<<"$tf_json" 2>/dev/null || echo "")
      if [[ -n "$task_role_name_out" && "$task_role_name_out" != "null" ]]; then
        ROLE_TASK_NAME="$task_role_name_out"
      fi
      if [[ -n "$exec_role_arn_out" && "$exec_role_arn_out" != "null" ]]; then
        # Derive name from ARN (last path segment)
        ROLE_EXEC_NAME="${exec_role_arn_out##*/}"
      fi
    fi
  fi
  [[ -n "$AWS_PROFILE_EFFECTIVE" ]] && info "Using AWS profile: $AWS_PROFILE_EFFECTIVE"
  [[ -n "$AWS_REGION_EFFECTIVE"  ]] && info "Using AWS region:  $AWS_REGION_EFFECTIVE"
}

check_role() {
  local role_name="$1"
  local arn trust policies
  arn=$(aws_cli iam get-role --role-name "$role_name" --query 'Role.Arn' --output text 2>/dev/null || true)
  [[ -n "$arn" && "$arn" != "None" ]] || { err "Role not found: $role_name"; exit 1; }
  ok "Role exists: $role_name ($arn)"

  trust=$(aws_cli iam get-role --role-name "$role_name" --query 'Role.AssumeRolePolicyDocument.Statement[0].Principal.Service' --output text)
  [[ "$trust" == *"ecs-tasks.amazonaws.com"* ]] || { err "Role $role_name trust not ecs-tasks.amazonaws.com (got: $trust)"; exit 1; }
  ok "Trust policy principal is ecs-tasks.amazonaws.com"
}

check_execution_role_policies() {
  local role_name="$1"
  local attached
  attached=$(aws_cli iam list-attached-role-policies --role-name "$role_name" --query 'AttachedPolicies[].PolicyArn' --output text)
  if grep -q 'arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy' <<<"$attached"; then
    ok "AmazonECSTaskExecutionRolePolicy is attached"
  else
    err "Missing AmazonECSTaskExecutionRolePolicy on $role_name"; exit 1
  fi
  info "Attached policies: $(tr '\n' ',' <<<"$attached" | sed 's/,$//')"

  # Ensure extra policy for Secrets/SSM is attached (from Lab 06)
  local extra_name="devops-refresher-staging-ecs-execution-extra"
  local extra_attached
  extra_attached=$(aws_cli iam list-attached-role-policies --role-name "$role_name" \
    --query 'AttachedPolicies[?PolicyName==`'"$extra_name"'`].PolicyArn' --output text || true)
  if [[ -z "$extra_attached" ]]; then
    err "Missing extra execution policy ($extra_name) for Secrets/SSM read on $role_name"; exit 1
  else
    ok "Extra execution policy attached: $extra_name"
  fi
}

main() {
  require aws
  parse_args "$@"
  discover_defaults

  info "Validating IAM execution role"
  check_role "$ROLE_EXEC_NAME"
  check_execution_role_policies "$ROLE_EXEC_NAME"

  info "Validating IAM task role"
  check_role "$ROLE_TASK_NAME"

  ok "IAM validation passed"
}

main "$@"
