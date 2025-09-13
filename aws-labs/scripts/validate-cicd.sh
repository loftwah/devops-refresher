#!/usr/bin/env bash
set -Eeuo pipefail

# Validates CI/CD integration for the labs:
# - Ensures artifacts S3 bucket policy grants BOTH CodePipeline and CodeBuild roles
#   the required actions (GetObject/GetObjectVersion/PutObject/GetBucketVersioning)
# - Ensures CodePipeline role inline policy contains required ECS actions for deploy
#
# Usage: ./validate-cicd.sh
# Environment is enforced by labs: profile devops-sandbox, region ap-southeast-2

PROFILE="devops-sandbox"
REGION="ap-southeast-2"

# Repo root (two levels up from aws-labs/scripts)
REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/../.. && pwd)
IAM_DIR="$REPO_ROOT/aws-labs/06-iam"
PIPE_DIR="$REPO_ROOT/aws-labs/15-cicd-ecs-pipeline"

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
aws_cli() { aws --profile "$PROFILE" --region "$REGION" "$@"; }

discover_context() {
  # Outputs from IAM lab (preferred)
  local iam_out
  if terraform -chdir="$IAM_DIR" init -input=false >/dev/null 2>&1; then
    iam_out=$(terraform -chdir="$IAM_DIR" output -json 2>/dev/null || echo '{}')
  else
    iam_out='{}'
  fi
  CODEPIPELINE_ROLE_ARN=$(jq -r '.codepipeline_role_arn.value // empty' <<<"$iam_out" || echo "")
  CODEBUILD_ROLE_ARN=$(jq -r '.codebuild_role_arn.value // empty' <<<"$iam_out" || echo "")

  # Fallback to default names if outputs missing
  if [[ -z "${CODEPIPELINE_ROLE_ARN:-}" ]]; then
    CODEPIPELINE_ROLE_ARN="arn:aws:iam::$(aws_cli sts get-caller-identity --query Account --output text):role/devops-refresher-codepipeline-role"
  fi
  if [[ -z "${CODEBUILD_ROLE_ARN:-}" ]]; then
    CODEBUILD_ROLE_ARN="arn:aws:iam::$(aws_cli sts get-caller-identity --query Account --output text):role/devops-refresher-codebuild-role"
  fi

  # Outputs from pipeline lab for artifacts bucket name
  local pipe_out pipe_json
  if terraform -chdir="$PIPE_DIR" init -input=false >/dev/null 2>&1; then
    pipe_out=$(terraform -chdir="$PIPE_DIR" output -json 2>/dev/null || echo '{}')
  else
    pipe_out='{}'
  fi
  ARTIFACTS_BUCKET=$(jq -r '.artifacts_bucket_name.value // empty' <<<"$pipe_out" || echo "")

  # Also discover the pipeline role actually configured on the pipeline
  pipe_json=$(aws_cli codepipeline get-pipeline --name devops-refresher-app-pipeline 2>/dev/null || echo '{}')
  PIPELINE_ROLE_ARN=$(jq -r '.pipeline.roleArn // empty' <<<"$pipe_json" || echo "")

  if [[ -z "$ARTIFACTS_BUCKET" || "$ARTIFACTS_BUCKET" == "null" ]]; then
    err "Could not discover artifacts bucket name from Terraform outputs. Ensure Lab 15 is applied, or set output 'artifacts_bucket_name'."
    exit 2
  fi

  CODEPIPELINE_ROLE_NAME=${CODEPIPELINE_ROLE_ARN##*/}
  CODEBUILD_ROLE_NAME=${CODEBUILD_ROLE_ARN##*/}

  info "Using AWS profile: $PROFILE"
  info "Using AWS region:  $REGION"
  info "Artifacts bucket:  $ARTIFACTS_BUCKET"
  info "CodePipeline role: $CODEPIPELINE_ROLE_NAME ($CODEPIPELINE_ROLE_ARN)"
  info "CodeBuild role:    $CODEBUILD_ROLE_NAME ($CODEBUILD_ROLE_ARN)"
}

json_contains_action_for_principal() {
  local json="$1" principal_arn="$2" action="$3"
  # Returns 0 if any Statement targets principal_arn and includes action
  jq -e --arg p "$principal_arn" --arg a "$action" '
    # Normalize Statement to an array
    (.Statement | if type=="array" then . else [.] end) as $stmts
    | [
        $stmts[]
        | . as $s
        | (
            ($s.Principal.AWS? // empty) as $aws
            | ((($aws|type)=="string" and $aws==$p) or (($aws|type)=="array" and ($aws|index($p))))
          )
          and (
            (($s.Action|type)=="string" and $s.Action==$a)
            or (($s.Action|type)=="array" and ($s.Action|index($a)))
          )
      ]
    | length > 0' >/dev/null <<<"$json"
}

check_bucket_policy() {
  info "Checking artifacts bucket policy principals and actions"
  local pol_json pol
  # Fetch full JSON, then extract and decode the Policy field like the working CLI example
  pol_json=$(aws_cli s3api get-bucket-policy --bucket "$ARTIFACTS_BUCKET" 2>/dev/null || echo '')
  [[ -n "$pol_json" ]] || { err "No bucket policy found on $ARTIFACTS_BUCKET"; exit 1; }
  pol=$(jq -r '.Policy | (try fromjson catch .)' <<<"$pol_json" 2>/dev/null || true)
  [[ -n "$pol" && "$pol" != "null" ]] || { err "Unable to parse bucket policy JSON for $ARTIFACTS_BUCKET"; exit 1; }

  local actions=("s3:GetObject" "s3:GetObjectVersion" "s3:PutObject" "s3:GetBucketVersioning")
  local ok_all=true
  for a in "${actions[@]}"; do
    if json_contains_action_for_principal "$pol" "$CODEPIPELINE_ROLE_ARN" "$a"; then
      ok "Bucket allows CodePipeline role: $a"
    else
      err "Bucket missing $a for CodePipeline role"; ok_all=false
    fi
    if json_contains_action_for_principal "$pol" "$CODEBUILD_ROLE_ARN" "$a"; then
      ok "Bucket allows CodeBuild role: $a"
    else
      err "Bucket missing $a for CodeBuild role"; ok_all=false
    fi
  done
  $ok_all || { err "Artifacts bucket policy check failed"; exit 1; }
  ok "Artifacts bucket policy grants required actions to both principals"
}

check_pipeline_role_ecs_permissions() {
  info "Checking CodePipeline role inline policy for ECS deploy actions"
  local pol_raw pol_decoded pol
  # AWS returns PolicyDocument URL-encoded. Fetch using JSON output to preserve quoting,
  # extract string with jq, then URL-decode and parse JSON.
  local get_out
  get_out=$(aws_cli iam get-role-policy \
    --role-name "$CODEPIPELINE_ROLE_NAME" \
    --policy-name devops-refresher-codepipeline \
    --output json)
  pol_raw=$(jq -r '.PolicyDocument // empty' <<<"$get_out" 2>/dev/null || echo "")
  [[ -n "$pol_raw" && "$pol_raw" != "null" ]] || { err "Unable to read inline policy from IAM for role $CODEPIPELINE_ROLE_NAME"; exit 1; }
  if command -v python3 >/dev/null 2>&1; then
    pol_decoded=$(python3 - <<'PY'
import sys, json
try:
    from urllib.parse import unquote_plus
except Exception:
    from urllib import unquote_plus  # type: ignore

s = sys.stdin.read()
s = unquote_plus(s)
# Try to parse JSON repeatedly until we have an object/array, not a string
def parse_recursive(x):
    try:
        obj = json.loads(x)
    except Exception:
        return x
    while isinstance(obj, str):
        try:
            obj = json.loads(obj)
        except Exception:
            break
    return obj

obj = parse_recursive(s)
if isinstance(obj, (dict, list)):
    print(json.dumps(obj))
else:
    print(s)
PY
    )
  elif command -v python >/dev/null 2>&1; then
    pol_decoded=$(python - <<'PY'
import sys, json
try:
    import urllib as u
except Exception:
    import urllib.parse as u  # type: ignore

s = sys.stdin.read()
s = u.unquote_plus(s)
def parse_recursive(x):
    try:
        obj = json.loads(x)
    except Exception:
        return x
    while isinstance(obj, basestring):  # type: ignore # noqa: F821
        try:
            obj = json.loads(obj)
        except Exception:
            break
    return obj

obj = parse_recursive(s)
if isinstance(obj, (dict, list)):
    print(json.dumps(obj))
else:
    print(s)
PY
    )
  else
    err "python3/python not found to decode PolicyDocument from IAM. Install Python to run validator."; exit 1
  fi
  # Keep both raw decoded text and normalized JSON (some jq versions struggle with nested encoding)
  pol_text="$pol_decoded"
  pol=$(jq -r 'if type=="string" then (try fromjson catch .) else . end' <<<"$pol_decoded")

  local required=(
    "ecs:ListClusters"
    "ecs:DescribeClusters"
    "ecs:ListServices"
    "ecs:DescribeServices"
    "ecs:DescribeTaskDefinition"
    "ecs:ListTaskDefinitions"
    "ecs:DescribeTasks"
    "ecs:DescribeTaskSets"
    "ecs:RegisterTaskDefinition"
    "ecs:UpdateService"
    "iam:PassRole"
  )
  local ok_all=true
  for a in "${required[@]}"; do
    if echo "$pol_text" | grep -q '"'"$a"'"'; then
      ok "Policy includes: $a"
    else
      err "Missing action in policy: $a"; ok_all=false
    fi
  done
  $ok_all || { err "CodePipeline role ECS permissions check failed"; exit 1; }
  ok "CodePipeline role inline policy includes required ECS actions"
}

check_pipeline_role_matches() {
  info "Checking pipeline is using the expected role"
  if [[ -z "$PIPELINE_ROLE_ARN" ]]; then
    err "Could not read pipeline.roleArn from CodePipeline configuration"; exit 1
  fi
  if [[ "$PIPELINE_ROLE_ARN" != "$CODEPIPELINE_ROLE_ARN" ]]; then
    err "Pipeline is using a different role: $PIPELINE_ROLE_ARN (expected $CODEPIPELINE_ROLE_ARN)"
    exit 1
  fi
  ok "Pipeline role matches expected IAM role"
}

check_ecs_targets_exist() {
  info "Checking ECS cluster and service existence"
  local cluster_status service_status
  cluster_status=$(aws_cli ecs describe-clusters --clusters devops-refresher-staging --query 'clusters[0].status' --output text 2>/dev/null || echo '')
  [[ "$cluster_status" == "ACTIVE" ]] || { err "ECS cluster 'devops-refresher-staging' not found/ACTIVE in $REGION"; exit 1; }
  service_status=$(aws_cli ecs describe-services --cluster devops-refresher-staging --services app --query 'services[0].status' --output text 2>/dev/null || echo '')
  [[ "$service_status" == "ACTIVE" ]] || { err "ECS service 'app' not found/ACTIVE in cluster 'devops-refresher-staging'"; exit 1; }
  ok "ECS targets found and ACTIVE"
}

main() {
  require aws; require jq; require terraform
  discover_context
  check_bucket_policy
  check_pipeline_role_matches
  check_ecs_targets_exist
  check_pipeline_role_ecs_permissions
  ok "CI/CD validation passed"
}

main "$@"
