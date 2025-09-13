#!/usr/bin/env bash
set -Eeuo pipefail

# Deploy the demo app to EKS via the in-repo Helm chart.
# Uses values from aws-labs/kubernetes/helm/demo-app/values-eks-staging-app.yaml

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)
CHART_PATH="${ROOT_DIR}/kubernetes/helm/demo-app"
VALUES_FILE="${ROOT_DIR}/kubernetes/helm/demo-app/values-eks-staging-app.yaml"
NAMESPACE="${NAMESPACE:-demo}"
RELEASE_NAME="${RELEASE_NAME:-demo}"
AWS_REGION="${AWS_REGION:-ap-southeast-2}"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET="\033[0m"; C_INFO="\033[36m"; C_OK="\033[32m"; C_FAIL="\033[31m"
else
  C_RESET=""; C_INFO=""; C_OK=""; C_FAIL=""
fi
info() { printf "${C_INFO}[INFO]${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_OK}[ OK ]${C_RESET} %s\n" "$*"; }
err()  { printf "${C_FAIL}[FAIL]${C_RESET} %s\n" "$*"; }
require() { command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found"; exit 1; }; }

main() {
  require aws; require helm; require kubectl

  # Discover cluster/cert from Terraform outputs
  local cluster_dir cert_dir cluster_name cert_arn
  cluster_dir="${ROOT_DIR}/17-eks-cluster"
  cert_dir="${ROOT_DIR}/18-eks-alb-externaldns"
  terraform -chdir="$cluster_dir" init -input=false >/dev/null || true
  cluster_name=$(terraform -chdir="$cluster_dir" output -raw cluster_name)
  terraform -chdir="$cert_dir" init -input=false >/dev/null || true
  cert_arn=$(terraform -chdir="$cert_dir" output -raw certificate_arn)

  info "Updating kubeconfig for cluster: $cluster_name ($AWS_REGION)"
  aws eks update-kubeconfig --name "$cluster_name" --region "$AWS_REGION" >/dev/null

  local set_args=()
  if [[ -n "${IMAGE_REPO:-}" ]]; then
    set_args+=(--set image.repository="$IMAGE_REPO")
  fi
  if [[ -n "${IMAGE_TAG:-}" ]]; then
    set_args+=(--set image.tag="$IMAGE_TAG")
  fi
  set_args+=(--set ingress.certificateArn="$cert_arn")

  info "Deploying Helm release: $RELEASE_NAME (ns=$NAMESPACE)"
  helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
    -n "$NAMESPACE" --create-namespace \
    -f "$VALUES_FILE" \
    "${set_args[@]}"

  info "Waiting for rollout"
  kubectl -n "$NAMESPACE" rollout status deploy/"$RELEASE_NAME" --timeout=5m
  ok "EKS app deployment complete"
}

main "$@"

