#!/usr/bin/env bash
set -Eeuo pipefail

# Deploy ECS Service (Primary entrypoint)
# - Discovers cluster, subnets, SGs, target group, IAM roles via tf outputs
# - Requires container image (ECR URL with tag), defaults to :staging for demo-node-app if discoverable

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)
LAB_DIR="$ROOT_DIR/aws-labs/14-ecs-service"
VPC_DIR="$ROOT_DIR/aws-labs/01-vpc"
SG_DIR="$ROOT_DIR/aws-labs/07-security-groups"
ALB_DIR="$ROOT_DIR/aws-labs/12-alb"
IAM_DIR="$ROOT_DIR/aws-labs/06-iam"
CLUSTER_DIR="$ROOT_DIR/aws-labs/13-ecs-cluster"
ECR_DIR="$ROOT_DIR/aws-labs/03-ecr"

# Basic colored output
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET="\033[0m"; C_INFO="\033[36m"; C_OK="\033[32m"; C_FAIL="\033[31m"
else
  C_RESET=""; C_INFO=""; C_OK=""; C_FAIL=""
fi
info() { printf "${C_INFO}[INFO]${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_OK}[ OK ]${C_RESET} %s\n" "$*"; }
err()  { printf "${C_FAIL}[FAIL]${C_RESET} %s\n" "$*"; }
require() { command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found"; exit 1; }; }

IMAGE=""
DESIRED_COUNT=1
CONTAINER_PORT=3000
SSM_PATH=""
INCLUDE_SSM=true

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i|--image) IMAGE="$2"; shift 2 ;;
      -c|--count) DESIRED_COUNT="$2"; shift 2 ;;
      -p|--port)  CONTAINER_PORT="$2"; shift 2 ;;
      --ssm-path) SSM_PATH="$2"; shift 2 ;;
      --no-ssm)   INCLUDE_SSM=false; shift 1 ;;
      -h|--help)
        cat <<EOF
Usage: $(basename "$0") [options]
  -i, --image URL     ECR image (e.g., <acct>.dkr.ecr.<region>.amazonaws.com/demo-node-app:staging)
  -c, --count N       Desired count (default: $DESIRED_COUNT)
  -p, --port  N       Container port (default: $CONTAINER_PORT)
      --ssm-path PATH  SSM/Secrets prefix (default: /devops-refresher/staging/app)
      --no-ssm         Do not read SSM/Secrets for env/secrets
EOF
        exit 0 ;;
      *) err "Unknown argument: $1"; exit 2 ;;
    esac
  done
}

discover_image_default() {
  # Try to form an image URL using ECR outputs and default :staging tag
  if [[ -z "$IMAGE" ]]; then
    if terraform -chdir="$ECR_DIR" init -input=false >/dev/null 2>&1; then
      local repo_url
      repo_url=$(terraform -chdir="$ECR_DIR" output -raw repository_url 2>/dev/null || true)
      if [[ -n "$repo_url" ]]; then
        IMAGE="${repo_url}:staging"
        info "Using default image: $IMAGE"
      fi
    fi
  fi
}

ensure_prereqs() {
  require terraform; require jq
  [[ -n "$IMAGE" ]] || { err "--image is required (or ensure ECR outputs available to infer)"; exit 1; }
}

resolve_ssm_path() {
  if [[ "$INCLUDE_SSM" != true ]]; then return 0; fi
  if [[ -n "$SSM_PATH" ]]; then return 0; fi
  # Try to read a default from Parameter Store lab output; fallback to standard path
  SSM_PATH="/devops-refresher/staging/app"
}

build_env_secrets_vars() {
  if [[ "$INCLUDE_SSM" != true ]]; then
    ENV_VARS_FILE=""
    return 0
  fi

  info "Collecting env from SSM and secrets from Secrets Manager under $SSM_PATH"
  # SSM parameters (non-sensitive)
  local env_json
  env_json=$(aws ssm get-parameters-by-path \
    --path "$SSM_PATH" \
    --with-decryption \
    --recursive \
    --query 'Parameters[].{Name:Name,Value:Value}' \
    --output json 2>/dev/null | jq -c '[.[] | {name: (.Name|split("/")|last), value: .Value}]' || echo '[]')

  # Secrets Manager (sensitive), match names with prefix
  local sec_json
  sec_json=$(aws secretsmanager list-secrets \
    --filters Key=name,Values="$SSM_PATH/" \
    --query 'SecretList[].{Name:Name,ARN:ARN}' \
    --output json 2>/dev/null | jq -c '[.[] | {name: (.Name|split("/")|last), valueFrom: .ARN}]' || echo '[]')

  # Write a temp tfvars.json that Terraform can consume directly
  ENV_VARS_FILE=$(mktemp "${TMPDIR:-/tmp}/ecs-env.XXXXXX.tfvars.json")
  jq -n --argjson env "$env_json" --argjson sec "$sec_json" '{environment: $env, secrets: $sec}' > "$ENV_VARS_FILE"
  info "Wrote env/secrets var file: $ENV_VARS_FILE"
}

apply_service() {
  info "Discovering prerequisites via Terraform outputs"
  terraform -chdir="$VPC_DIR" init -input=false >/dev/null
  terraform -chdir="$SG_DIR" init -input=false >/dev/null
  terraform -chdir="$ALB_DIR" init -input=false >/dev/null || true
  terraform -chdir="$IAM_DIR" init -input=false >/dev/null || true
  terraform -chdir="$CLUSTER_DIR" init -input=false >/dev/null

  local SUBNETS SG APP_SG TG CLUSTER_ARN EXEC_ARN TASK_ARN
  SUBNETS=$(terraform -chdir="$VPC_DIR" output -json private_subnet_ids | jq -r '.[]' | paste -sd, -)
  APP_SG=$(terraform -chdir="$SG_DIR" output -raw app_sg_id)
  TG=$(terraform -chdir="$ALB_DIR" output -raw tg_arn)
  CLUSTER_ARN=$(terraform -chdir="$CLUSTER_DIR" output -raw cluster_arn)
  EXEC_ARN=$(terraform -chdir="$IAM_DIR" output -raw execution_role_arn 2>/dev/null || echo "")
  TASK_ARN=$(terraform -chdir="$IAM_DIR" output -raw task_role_arn 2>/dev/null || echo "")

  info "Applying ECS service in $LAB_DIR"
  terraform -chdir="$LAB_DIR" init -input=false
  if [[ -n "${ENV_VARS_FILE:-}" ]]; then
    VAR_FILE_ARG=( -var-file "$ENV_VARS_FILE" )
  else
    VAR_FILE_ARG=()
  fi
  terraform -chdir="$LAB_DIR" apply \
    -auto-approve \
    -var cluster_arn="$CLUSTER_ARN" \
    -var "subnet_ids=[$SUBNETS]" \
    -var "security_group_ids=['$APP_SG']" \
    -var target_group_arn="$TG" \
    ${EXEC_ARN:+-var execution_role_arn="$EXEC_ARN"} \
    ${TASK_ARN:+-var task_role_arn="$TASK_ARN"} \
    -var image="$IMAGE" \
    -var container_port="$CONTAINER_PORT" \
    -var desired_count="$DESIRED_COUNT" \
    "${VAR_FILE_ARG[@]}"
  ok "ECS service applied"
  terraform -chdir="$LAB_DIR" output
}

main() {
  parse_args "$@"
  discover_image_default
  ensure_prereqs
  resolve_ssm_path
  build_env_secrets_vars
  apply_service
}

main "$@"

