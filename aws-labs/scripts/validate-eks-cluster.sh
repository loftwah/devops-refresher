#!/usr/bin/env bash
set -Eeuo pipefail

# Validates EKS cluster from aws-labs/17-eks-cluster
# - Confirms cluster ACTIVE in ap-southeast-2
# - Node group Ready
# - OIDC provider exists
# - Public/private subnets tagged for cluster + ELB role

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)
EKS_DIR="$ROOT_DIR/17-eks-cluster"
VPC_DIR="$ROOT_DIR/01-vpc"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET="\033[0m"; C_INFO="\033[36m"; C_OK="\033[32m"; C_FAIL="\033[31m"
else
  C_RESET=""; C_INFO=""; C_OK=""; C_FAIL=""
fi
info() { printf "${C_INFO}[INFO]${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_OK}[ OK ]${C_RESET} %s\n" "$*"; }
err()  { printf "${C_FAIL}[FAIL]${C_RESET} %s\n" "$*"; }
require() { command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found"; exit 1; }; }

PROFILE="devops-sandbox"
REGION="ap-southeast-2"

aws_cli() {
  aws --profile "$PROFILE" --region "$REGION" "$@"
}

read_tf_outputs() {
  require terraform; require jq
  terraform -chdir="$EKS_DIR" init -input=false >/dev/null
  local eks_out
  eks_out=$(terraform -chdir="$EKS_DIR" output -json)
  CLUSTER_NAME=$(jq -r '.cluster_name.value' <<<"$eks_out")
  OIDC_ARN=$(jq -r '.oidc_provider_arn.value' <<<"$eks_out")
  [[ -n "$CLUSTER_NAME" && "$CLUSTER_NAME" != "null" ]] || { err "Missing cluster_name output"; exit 1; }

  terraform -chdir="$VPC_DIR" init -input=false >/dev/null
  local vpc_out
  vpc_out=$(terraform -chdir="$VPC_DIR" output -json)
  mapfile -t PUB_SUBNETS < <(jq -r '.public_subnet_ids.value[]' <<<"$vpc_out")
  mapfile -t PRIV_SUBNETS < <(jq -r '.private_subnet_ids.value[]' <<<"$vpc_out")
}

check_cluster() {
  local status
  status=$(aws_cli eks describe-cluster --name "$CLUSTER_NAME" --query 'cluster.status' --output text 2>/dev/null || echo '')
  [[ "$status" == "ACTIVE" ]] || { err "EKS cluster '$CLUSTER_NAME' not ACTIVE in $REGION"; exit 1; }
  ok "Cluster $CLUSTER_NAME is ACTIVE"
}

check_nodegroup() {
  local ng_name state
  # Attempt to discover the single nodegroup
  ng_name=$(aws_cli eks list-nodegroups --cluster-name "$CLUSTER_NAME" --query 'nodegroups[0]' --output text 2>/dev/null || echo '')
  [[ -n "$ng_name" && "$ng_name" != "None" ]] || { err "No node groups found for $CLUSTER_NAME"; exit 1; }
  state=$(aws_cli eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng_name" --query 'nodegroup.status' --output text)
  [[ "$state" == "ACTIVE" ]] || { err "Node group '$ng_name' not ACTIVE (got: $state)"; exit 1; }
  ok "Node group $ng_name is ACTIVE"
}

check_oidc() {
  [[ -n "${OIDC_ARN:-}" && "$OIDC_ARN" != "null" ]] || { err "Missing OIDC provider ARN output"; exit 1; }
  aws_cli iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" >/dev/null
  ok "OIDC provider present: $OIDC_ARN"
}

check_subnet_tags() {
  local ok_tags=1
  for id in "${PUB_SUBNETS[@]}"; do
    local have_elb have_cluster
    have_elb=$(aws_cli ec2 describe-tags --filters "Name=resource-id,Values=$id" "Name=key,Values=kubernetes.io/role/elb" --query 'Tags[0].Value' --output text 2>/dev/null || echo '')
    have_cluster=$(aws_cli ec2 describe-tags --filters "Name=resource-id,Values=$id" "Name=key,Values=kubernetes.io/cluster/${CLUSTER_NAME}" --query 'Tags[0].Value' --output text 2>/dev/null || echo '')
    [[ "$have_elb" == "1" && "$have_cluster" == "shared" ]] || ok_tags=0
  done
  for id in "${PRIV_SUBNETS[@]}"; do
    local have_cluster
    have_cluster=$(aws_cli ec2 describe-tags --filters "Name=resource-id,Values=$id" "Name=key,Values=kubernetes.io/cluster/${CLUSTER_NAME}" --query 'Tags[0].Value' --output text 2>/dev/null || echo '')
    [[ "$have_cluster" == "shared" ]] || ok_tags=0
  done
  (( ok_tags == 1 )) || { err "Missing required subnet tags for cluster/ELB"; exit 1; }
  ok "Subnet tags present for cluster and ELB role"
}

main() {
  require aws; require jq
  read_tf_outputs
  check_cluster
  check_nodegroup
  check_oidc
  check_subnet_tags
  ok "EKS cluster validation passed"
}

main "$@"

