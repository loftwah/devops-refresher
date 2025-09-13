#!/usr/bin/env bash
set -Eeuo pipefail

# Validates Lab 20 – EKS App (Helm)
# - Deployment ready, Service present
# - Ingress has address and expected host
# - ExternalSecret (if enabled) is Synced
# - Optional: HTTPS health check

APP_HOST="demo-node-app-eks.aws.deanlofts.xyz"
NAMESPACE="demo"
RELEASE_NAME="demo"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET="\033[0m"; C_INFO="\033[36m"; C_OK="\033[32m"; C_FAIL="\033[31m"
else
  C_RESET=""; C_INFO=""; C_OK=""; C_FAIL=""
fi
info() { printf "${C_INFO}[INFO]${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_OK}[ OK ]${C_RESET} %s\n" "$*"; }
err()  { printf "${C_FAIL}[FAIL]${C_RESET} %s\n" "$*"; }
require() { command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found"; exit 1; }; }

check_kubectl() {
  require kubectl
  kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || { err "Namespace '$NAMESPACE' not found"; exit 1; }
}

check_workloads() {
  local ready
  ready=$(kubectl -n "$NAMESPACE" get deploy "$RELEASE_NAME" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo '')
  [[ "$ready" =~ ^[1-9] ]] || { err "Deployment '$RELEASE_NAME' not ready"; exit 1; }
  ok "Deployment ready replicas: $ready"

  kubectl -n "$NAMESPACE" get svc "$RELEASE_NAME" >/dev/null || { err "Service '$RELEASE_NAME' missing"; exit 1; }
  ok "Service present"
}

check_ingress() {
  local host addr
  host=$(kubectl -n "$NAMESPACE" get ingress "$RELEASE_NAME" -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo '')
  [[ "$host" == "$APP_HOST" ]] || { err "Ingress host mismatch (got: $host)"; exit 1; }
  addr=$(kubectl -n "$NAMESPACE" get ingress "$RELEASE_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo '')
  [[ -n "$addr" ]] || { err "Ingress has no LoadBalancer address yet"; exit 1; }
  ok "Ingress hostname: $addr"
}

check_externalsecret() {
  # ExternalSecret created by chart is named '<release>-externalsecret'
  if kubectl -n "$NAMESPACE" get externalsecret "$RELEASE_NAME-externalsecret" >/dev/null 2>&1; then
    local cond
    cond=$(kubectl -n "$NAMESPACE" get externalsecret "$RELEASE_NAME-externalsecret" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
    [[ "$cond" == "True" ]] || { err "ExternalSecret not Ready"; exit 1; }
    ok "ExternalSecret is Ready"
  else
    info "ExternalSecret not found; chart may be running with explicit env"
  fi
}

check_https() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsS "https://$APP_HOST/healthz" >/dev/null && ok "HTTPS health check OK" || { err "HTTPS health check failed"; exit 1; }
  else
    info "curl not installed; skipping HTTPS check"
  fi
}

main() {
  check_kubectl
  check_workloads
  check_ingress
  check_externalsecret
  check_https
  ok "EKS app validation passed"
}

main "$@"

