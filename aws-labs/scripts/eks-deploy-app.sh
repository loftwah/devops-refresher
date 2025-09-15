#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)
CHART_PATH="${ROOT_DIR}/kubernetes/helm/demo-app"
VALUES_FILE="${ROOT_DIR}/kubernetes/helm/demo-app/values.yml"
NAMESPACE="${NAMESPACE:-demo}"
RELEASE_NAME="${RELEASE_NAME:-demo}"
AWS_REGION="${AWS_REGION:-ap-southeast-2}"
PROFILE="${PROFILE:-devops-sandbox}"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET="\033[0m"; C_INFO="\033[36m"; C_OK="\033[32m"; C_FAIL="\033[31m"
else
  C_RESET=""; C_INFO=""; C_OK=""; C_FAIL=""
fi
info() { printf "${C_INFO}[INFO]${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_OK}[ OK ]${C_RESET} %s\n" "$*"; }
err()  { printf "${C_FAIL}[FAIL]${C_RESET} %s\n" "$*"; }
require() { command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found"; exit 1; }; }

aws_cli() {
  aws --profile "$PROFILE" --region "$AWS_REGION" "$@"
}

main() {
  require aws; require helm; require kubectl
  local cluster_dir cert_dir cluster_name cert_arn
  cluster_dir="${ROOT_DIR}/17-eks-cluster"
  cert_dir="${ROOT_DIR}/18-eks-alb-externaldns"
  terraform -chdir="$cluster_dir" init -input=false >/dev/null || true
  cluster_name="${CLUSTER_NAME:-$(terraform -chdir="$cluster_dir" output -raw cluster_name)}"
  terraform -chdir="$cert_dir" init -input=false >/dev/null || true
  cert_arn=$(terraform -chdir="$cert_dir" output -raw certificate_arn)

  info "Updating kubeconfig for cluster: $cluster_name ($AWS_REGION, profile=$PROFILE)"
  if ! aws_cli eks describe-cluster --name "$cluster_name" >/dev/null 2>&1; then
    err "Cluster not found or not accessible: $cluster_name (region=$AWS_REGION, profile=$PROFILE)"; exit 1;
  fi
  aws_cli eks update-kubeconfig --name "$cluster_name" >/dev/null

  if [[ -z "${IMAGE_TAG:-}" && -n "${CODEBUILD_RESOLVED_SOURCE_VERSION:-}" ]]; then
    IMAGE_TAG="$(echo "$CODEBUILD_RESOLVED_SOURCE_VERSION" | cut -c1-7)"
  fi
  if [[ -z "${BUILD_VERSION:-}" ]]; then
    if [[ -n "${CODEBUILD_RESOLVED_SOURCE_VERSION:-}" ]]; then
      BUILD_VERSION="$(echo "$CODEBUILD_RESOLVED_SOURCE_VERSION" | cut -c1-7)"
    else
      BUILD_VERSION="$(date +%s)"
    fi
  fi

  if [[ -z "${IMAGE_TAG:-}" && -z "${IMAGE_DIGEST:-}" ]]; then
    local repo_from_values tag_from_values ecr_repo_name digest latest_digest latest_tag t block
    block=$(sed -n '/^image:[[:space:]]*$/,/^[^[:space:]]/p' "$VALUES_FILE")
    repo_from_values=$(printf '%s\n' "$block" | grep -E '^[[:space:]]+repository:' | head -1 | sed -E 's/^[^:]+:[[:space:]]*//; s/^"//; s/"$//')
    tag_from_values=$(printf '%s\n' "$block" | grep -E '^[[:space:]]+tag:' | head -1 | sed -E 's/^[^:]+:[[:space:]]*//; s/^"//; s/"$//')
    if [[ -n "$repo_from_values" ]]; then IMAGE_REPO="$repo_from_values"; fi
    if [[ -z "${IMAGE_REPO:-}" ]]; then err "image.repository not found in $VALUES_FILE"; exit 1; fi
    ecr_repo_name="${IMAGE_REPO##*/}"
    latest_digest=$(aws_cli ecr describe-images --repository-name "$ecr_repo_name" --query 'reverse(sort_by(imageDetails,&imagePushedAt))[0].imageDigest' --output text 2>/dev/null || echo "")
    latest_tag=""
    while IFS= read -r t; do
      if [[ "$t" =~ ^[0-9a-f]{7}$ ]]; then latest_tag="$t"; break; fi
    done < <(aws_cli ecr describe-images --repository-name "$ecr_repo_name" --query 'reverse(sort_by(imageDetails,&imagePushedAt))[].imageTags[]' --output text 2>/dev/null | tr '\t' '\n')
    if [[ -n "$latest_tag" ]]; then IMAGE_TAG="$latest_tag"; fi
    if [[ -n "$latest_digest" && "$latest_digest" != "None" ]]; then IMAGE_DIGEST="$latest_digest"; fi
    if [[ -z "${IMAGE_DIGEST:-}" && -n "$tag_from_values" ]]; then
      digest=$(aws_cli ecr describe-images --repository-name "$ecr_repo_name" --image-ids imageTag="$tag_from_values" --query 'imageDetails[0].imageDigest' --output text 2>/dev/null || echo "")
      if [[ -n "$digest" && "$digest" != "None" ]]; then IMAGE_DIGEST="$digest"; IMAGE_TAG="$tag_from_values"; fi
    fi
    :
  fi

  local set_args=()
  if [[ -n "${IMAGE_REPO:-}" ]]; then
    set_args+=(--set image.repository="$IMAGE_REPO")
  fi
  if [[ -n "${IMAGE_TAG:-}" ]]; then
    set_args+=(--set image.tag="$IMAGE_TAG")
  fi
  if [[ -n "${IMAGE_DIGEST:-}" ]]; then
    set_args+=(--set image.digest="$IMAGE_DIGEST")
  fi
  set_args+=(--set image.pullPolicy=Always)
  set_args+=(--set buildVersion="$BUILD_VERSION")
  set_args+=(--set ingress.certificateArn="$cert_arn")
  if ! kubectl api-resources --api-group=external-secrets.io | grep -q ExternalSecret; then
    info "ExternalSecret CRD not found; disabling externalSecrets in this deploy"
    set_args+=(--set externalSecrets.enabled=false)
  fi

  info "Deploying Helm release: $RELEASE_NAME (ns=$NAMESPACE)"
  helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
    -n "$NAMESPACE" --create-namespace \
    -f "$VALUES_FILE" \
    --set fullnameOverride="$RELEASE_NAME" \
    --wait --atomic --timeout 10m \
    "${set_args[@]}"

  info "Waiting for rollout"
  kubectl -n "$NAMESPACE" rollout status deploy/"$RELEASE_NAME" --timeout=5m
  ok "EKS app deployment complete"
}

main "$@"
