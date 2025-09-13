#!/usr/bin/env bash
set -Eeuo pipefail

# Fails if any script under aws-labs/scripts uses forbidden profile/region patterns.
# Allowed exception: validate-backend.sh can use backend region parsing (us-east-1) only.

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)
SCRIPTS_DIR="$ROOT_DIR/aws-labs/scripts"

for f in $(find "$SCRIPTS_DIR" -type f -name "*.sh" ! -name "check-enforcement.sh"); do
  if grep -Eq '(-p\|--profile|AWS_PROFILE|--profile |AWS_REGION|--region )' "$f"; then
    case "$f" in
      *validate-backend.sh) ;;
      *) echo "[FAIL] Forbidden profile/region usage in $f" >&2; exit 1 ;;
    esac
  fi
done

echo "[OK] All scripts enforce devops-sandbox / ap-southeast-2 (with backend exception)."
