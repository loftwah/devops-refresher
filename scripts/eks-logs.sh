#!/usr/bin/env bash
set -Eeuo pipefail

# kubectl logs wrapper with namespace + selector
# Usage: eks-logs.sh [-n namespace] [-l selector] [-- since SECS]

NS=default
SEL="app=demo"
SINCE="1h"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace) NS="$2"; shift 2 ;;
    -l|--selector)  SEL="$2"; shift 2 ;;
    --since)        SINCE="$2"; shift 2 ;;
    -h|--help) echo "Usage: $0 [-n namespace] [-l selector] [--since 1h]"; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

PODS=$(kubectl get pods -n "$NS" -l "$SEL" -o name)
for p in $PODS; do
  echo "==== $p ===="
  kubectl logs -n "$NS" "$p" --since "$SINCE" --all-containers=true || true
done

