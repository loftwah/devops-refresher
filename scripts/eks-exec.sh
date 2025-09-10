#!/usr/bin/env bash
set -Eeuo pipefail

# kubectl exec into the first pod matching a selector
# Usage: eks-exec.sh [-n namespace] [-l selector] [-- cmd]

NS=default
SEL="app=demo"
CMD="/bin/sh"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace) NS="$2"; shift 2 ;;
    -l|--selector)  SEL="$2"; shift 2 ;;
    --) shift; CMD="$*"; break ;;
    -h|--help) echo "Usage: $0 [-n namespace] [-l selector] [-- cmd]"; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

POD=$(kubectl get pods -n "$NS" -l "$SEL" -o jsonpath='{.items[0].metadata.name}')
[[ -n "$POD" ]] || { echo "No pod found for selector: $SEL"; exit 1; }

echo "Exec into $POD"
kubectl exec -it -n "$NS" "$POD" -- $CMD

