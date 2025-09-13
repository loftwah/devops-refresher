#!/usr/bin/env bash
set -Eeuo pipefail

# Validates Lab 19 – EKS External Secrets
# - IRSA role exists
# - ESO ServiceAccount annotated with that role (if ESO installed)
# - ClusterSecretStores exist (parameterstore, secretsmanager)

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)
LAB_DIR="$ROOT_DIR/19-eks-external-secrets"

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
  terraform -chdir="$LAB_DIR" init -input=false >/dev/null
  local out
  out=$(terraform -chdir="$LAB_DIR" output -json)
  ESO_ROLE_ARN=$(jq -r '.role_arn.value' <<<"$out")
  [[ -n "$ESO_ROLE_ARN" && "$ESO_ROLE_ARN" != "null" ]] || { err "Missing ESO role_arn output"; exit 1; }
}

check_role() {
  aws_cli iam get-role --role-name "${ESO_ROLE_ARN##*/}" >/dev/null
  ok "ESO role exists: $ESO_ROLE_ARN"
}

check_k8s_objects() {
  if ! command -v kubectl >/dev/null 2>&1; then
    info "kubectl not installed; skipping Kubernetes checks"
    return
  fi
  # SA annotation
  if kubectl -n external-secrets get sa external-secrets >/dev/null 2>&1; then
    local ann
    ann=$(kubectl -n external-secrets get sa external-secrets -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null || true)
    [[ "$ann" == "$ESO_ROLE_ARN" ]] || { err "ESO SA annotation mismatch"; exit 1; }
    ok "ESO ServiceAccount annotated with role"
  else
    info "ESO ServiceAccount not found; ensure ESO is installed"
  fi
  # ClusterSecretStores
  if kubectl get clustersecretstore aws-parameterstore >/dev/null 2>&1; then
    ok "ClusterSecretStore aws-parameterstore present"
  else
    err "ClusterSecretStore aws-parameterstore missing"; exit 1
  fi
  if kubectl get clustersecretstore aws-secretsmanager >/dev/null 2>&1; then
    ok "ClusterSecretStore aws-secretsmanager present"
  else
    err "ClusterSecretStore aws-secretsmanager missing"; exit 1
  fi
}

main() {
  require aws; require jq
  read_tf_outputs
  check_role
  check_k8s_objects
  ok "EKS External Secrets validation passed"
}

main "$@"

