# Slack CI/CD Notifications (Loftwah Reference)

This is a plain‑English walkthrough of the Slack notifications system I built for CI/CD. It explains the why, what, where, and how — including where the Python lives, how it becomes a Lambda, and how it hooks into CodePipeline.

Short version: CodePipeline/CodeBuild events → CodeStar Notifications → SNS → Lambda (Python) → Slack Incoming Webhook.

## Why (Problem → Design)

- Need: See pipeline and build status in Slack with useful context (links, emojis, approvals, environment info).
- Constraints: Keep it simple, infra‑as‑code, and avoid heavy Slack OAuth/apps.
- Design choice: Use a small Python Lambda that formats events exactly how Loftwah wants and posts to a Slack Incoming Webhook URL.
  - Pros: Full control of formatting/mentions/routing, vendor dependencies once, easy to reuse across pipelines.
  - Cons: One secret (webhook URL) to manage; Lambda to maintain.

## What (The Pieces)

- Event source: CodePipeline and CodeBuild state changes.
- Delivery bus: CodeStar Notifications targets an SNS topic.
- Processor: A Python Lambda subscribed to the SNS topic, formats messages and posts to Slack.
- Secret/config: Slack webhook URL provided to the Lambda via env var (or SSM, if you prefer).

## Where (In Your Repo)

- Lambda code and packaging (staging):
  - Python entrypoint: `staging/cicd/lambda-slack-notifier/src/slack_notifier.py:1`
  - Vendored deps (requests, certifi, etc.) inside `src/` to avoid layers: `staging/cicd/lambda-slack-notifier/src`
  - Zip packaging: `staging/cicd/lambda-slack-notifier/main.tf:1` (`archive_file` zips `src/` into `lambda_payload.zip`)
  - IAM/Logs/DLQ: `staging/cicd/lambda-slack-notifier/iam.tf:1`, `cloudwatch.tf:1`, `sqs.tf:1`
  - Module outputs (Lambda ARN/name): `staging/cicd/lambda-slack-notifier/outputs.tf:1`
  - Test events (helpful for Console tests): `staging/cicd/lambda-slack-notifier/test/*.json`
- SNS + subscription (per app):
  - Web: `staging/cicd/classtag_web/sns.tf:1`
  - Clicks: `staging/cicd/classtag_clicks/sns.tf:1`
  - Connect Client: `staging/cicd/classtag_connect_client/sns.tf:1`
- CodeStar Notification rules (examples):
  - Web: `staging/cicd/classtag_web/codepipeline.tf:112`, `staging/cicd/classtag_web/codebuild.tf:226`
  - Clicks: `staging/cicd/classtag_clicks/codepipeline.tf:88`, `staging/cicd/classtag_clicks/codebuild.tf:114`
  - Connect Client: `staging/cicd/classtag_connect_client/codepipeline.tf:88`, `staging/cicd/classtag_connect_client/codebuild.tf:112`

Tip: The same pattern is repeated for production under `production/cicd/...` with its own topics and rules.

## How (End‑to‑End Flow)

1. CodePipeline/CodeBuild changes state (started, succeeded, failed, approval, etc.).
2. A CodeStar Notifications rule for that resource fires and publishes a message to a build notifications SNS topic.
3. The SNS topic has a Lambda subscription pointing to the Slack notifier. SNS invokes the Lambda.
4. The Lambda parses the SNS message, builds a Slack payload (blocks/markdown) with emojis, deep links, env context, and posts to the Slack Incoming Webhook URL.

Console links in messages let you jump straight to the execution/build. Approvals are formatted with who/what/where when the data is present.

## AWS Resources Involved

- CodePipeline: `aws_codepipeline` — source/build/deploy stages raise events.
- CodeBuild: `aws_codebuild_project` — build events included if desired.
- CodeStar Notifications: `aws_codestarnotifications_notification_rule` — chooses event types and targets SNS.
- SNS:
  - Topic: `aws_sns_topic` — event fan‑out target.
  - Policy: `aws_sns_topic_policy` — allow CodeStar Notifications to publish.
  - Subscription: `aws_sns_topic_subscription` (protocol `lambda`) — invoke the formatter Lambda.
- Lambda:
  - Function: `aws_lambda_function` — formats Slack messages and posts to webhook.
  - Permission: `aws_lambda_permission` — allow `sns.amazonaws.com` to invoke.
  - Logs: `aws_cloudwatch_log_group` — Lambda logs.
- Config/Secrets:
  - SSM Parameter (optional): `aws_ssm_parameter` — can store Slack webhook URL and optional config (SecureString). In this repo, the webhook is passed as a TF var/env var.
- IAM:
  - Role: `aws_iam_role` — Lambda execution.
  - Policy: `aws_iam_policy` / `aws_iam_role_policy` / `aws_iam_role_policy_attachment` — Logs, SSM, optional KMS, and (if needed) VPC ENI permissions.

Optional supporting infra: VPC/subnets/security groups if Lambda runs in VPC (not required here).

## Values Needed and Where They Come From

- Slack:
  - Webhook URL: Created in Loftwah’s Slack workspace (Slack App → Incoming Webhooks). Stored in SSM as SecureString.
  - Channel name: Default in Lambda env/SSM; can be overridden per message.
  - Optional: display name/icon; mention list (e.g., `@devops`) for failures.
- AWS:
  - SNS topic ARN: Output from `aws_sns_topic` for notification rule target.
  - Lambda ARN: For SNS subscription and permission.
  - Optional SSM parameter names: e.g., `/<env>/loftwah/slack/webhook_url`, if you switch to SSM for the webhook.
  - KMS key (optional): If SSM SecureString uses a CMK, Lambda needs decrypt rights.

## Event Coverage and Filtering

- CodePipeline event types (examples): Pipeline execution started/succeeded/failed/canceled; Stage execution started/succeeded/failed; Action execution succeeded/failed.
- CodeBuild event types (optional): Build in‑progress/succeeded/failed/stopped.
- Configure in `aws_codestarnotifications_notification_rule.event_type_ids` per source (pipeline and/or build project).
- Tip: Start with only “failed” + “succeeded”; add “started” if needed.

## Permissions

- CodeStar Notifications → SNS:
  - `aws_sns_topic_policy` allows `codestar-notifications.amazonaws.com` to `Publish` to the topic in your account.
- SNS → Lambda:
  - `aws_lambda_permission` with `principal = "sns.amazonaws.com"` and `source_arn = <topic_arn>`.
- Lambda execution role:
  - Logs: `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`.
  - SSM: `ssm:GetParameter`, `ssm:GetParameters` (limit to exact parameter paths).
  - KMS (if SecureString with CMK): `kms:Decrypt` on the key.
  - Networking (if in VPC): `ec2:CreateNetworkInterface`, `ec2:Describe*`, `ec2:DeleteNetworkInterface`.
  - SNS topic policy: include a `Condition` to restrict `sns:Publish` to your account via `aws:SourceAccount`.

## Lambda Message Formatting (Behavior)

Inputs: SNS message containing CodeStar Notifications detail (pipeline/build status).

Key behavior:

- Parse detail to identify pipeline, stage, action, executionId, region, account, and status.
- Map statuses to colors/emojis; mention roles/groups on failures.
- Build Slack payload with blocks/attachments; include deep links to CodePipeline/CodeBuild console.
- Post to Slack via webhook (HTTP POST).

Suggested configuration (env vars or SSM):

- `SLACK_WEBHOOK_URL_SSM_PARAM` — SSM name for webhook URL.
- `SLACK_DEFAULT_CHANNEL` — e.g., `#loftwah-cicd`.
- `SLACK_USERNAME` — e.g., `Loftwah CI/CD`.
- `SLACK_ICON_EMOJI` — e.g., `:rocket:`.
- `SLACK_MENTION_ON_FAILURE` — e.g., `@devops` or empty.
- `MESSAGE_VERBOSITY` — `summary|full`.

Error handling:

- Allow SNS/Lambda retries; log payload and reason on Slack 4xx.
- DLQ (optional): Configure Lambda DLQ and alert via CloudWatch Alarm.

## Terraform Mapping (Resource Cheatsheet)

- `aws_codestarnotifications_notification_rule`:
  - `resource` = CodePipeline ARN or CodeBuild project ARN.
  - `event_type_ids` = list of events to watch.
  - `target { type = "SNS", address = <sns_topic_arn> }`.
  - `detail_type` = `FULL` for richer payloads.
- `aws_sns_topic` and `aws_sns_topic_policy`:
  - Policy statement principal: `codestar-notifications.amazonaws.com` with `Condition.StringEquals = { "aws:SourceAccount" = <your_account_id> }`.
- `aws_sns_topic_subscription`:
  - `protocol = "lambda"`, `endpoint = <lambda_arn>`.
- `aws_lambda_function`:
  - Runtime/handler/role; env vars pointing at SSM parameter names and defaults.
  - VPC config (if needed).
- `aws_lambda_permission`:
  - `action = "lambda:InvokeFunction"`, `principal = "sns.amazonaws.com"`, `source_arn = <sns_topic_arn>`.
- `aws_ssm_parameter`:
  - `type = "SecureString"`, `name = "/<env>/loftwah/slack/webhook_url"`.
- `aws_cloudwatch_log_group`:
  - Optional explicit resource; else Lambda auto‑creates.

## Minimal Terraform Stubs (Loftwah-Safe Placeholders)

```hcl
resource "aws_sns_topic" "loftwah_cicd_notifications" {
  name = "loftwah-cicd-notifications"
}

resource "aws_sns_topic_policy" "allow_codestar_publish" {
  arn    = aws_sns_topic.loftwah_cicd_notifications.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codestar-notifications.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.loftwah_cicd_notifications.arn
      Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } }
    }]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_lambda_function" "slack_notifier" {
  function_name = "loftwah-slack-notifier"
  role          = aws_iam_role.lambda_exec.arn
  filename      = var.slack_notifier_package   # e.g. local zip
  handler       = "handler.main"
  runtime       = "python3.11"
  environment {
    variables = {
      SLACK_WEBHOOK_URL_SSM_PARAM = "/${var.env}/loftwah/slack/webhook_url"
      SLACK_DEFAULT_CHANNEL       = "#loftwah-cicd"
      SLACK_USERNAME              = "Loftwah CI/CD"
      SLACK_ICON_EMOJI            = ":rocket:"
      SLACK_MENTION_ON_FAILURE    = "@devops"
      MESSAGE_VERBOSITY           = "summary"
    }
  }
}

resource "aws_lambda_permission" "allow_sns_invoke" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.loftwah_cicd_notifications.arn
}

resource "aws_sns_topic_subscription" "slack_notifier" {
  topic_arn = aws_sns_topic.loftwah_cicd_notifications.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notifier.arn
}

resource "aws_ssm_parameter" "slack_webhook_url" {
  name  = "/${var.env}/loftwah/slack/webhook_url"
  type  = "SecureString"
  value = var.slack_webhook_url_placeholder  # set via TF var or later via console
}

resource "aws_codestarnotifications_notification_rule" "pipeline_rule" {
  name         = "loftwah-${var.env}-pipeline-notifications"
  detail_type  = "FULL"
  resource     = aws_codepipeline.main.arn
  event_type_ids = [
    "codepipeline-pipeline-pipeline-execution-succeeded",
    "codepipeline-pipeline-pipeline-execution-failed"
  ]
  target {
    type    = "SNS"
    address = aws_sns_topic.loftwah_cicd_notifications.arn
  }
}

# Example IAM for Lambda (tighten to exact ARNs/paths in real use)
resource "aws_iam_role" "lambda_exec" {
  name               = "loftwah-slack-notifier-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_exec_inline" {
  name = "loftwah-slack-notifier-inline"
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "*" },
      # Scope SSM access to exactly your webhook parameter ARN (replace region/account/env)
      { Effect = "Allow", Action = ["ssm:GetParameter", "ssm:GetParameters"], Resource = "arn:aws:ssm:us-east-1:123456789012:parameter/*/loftwah/slack/webhook_url" }
    ]
  })
}
```

> Note: Replace wildcards with exact ARNs and parameter paths in production. If your SSM parameter is encrypted with a CMK, add `kms:Decrypt` scoped to that key.

## The Python → Lambda Packaging (This Repo’s Pattern)

- Files of interest:
  - `staging/cicd/lambda-slack-notifier/main.tf:1` — uses `archive_file` to zip everything under `src/` into `lambda_payload.zip`, then points the `aws_lambda_function` at that zip.
  - `staging/cicd/lambda-slack-notifier/src/slack_notifier.py:1` — the Lambda handler (`slack_notifier.lambda_handler`).
  - `staging/cicd/lambda-slack-notifier/src/` — includes vendored Python dependencies (`requests`, etc.) so the zip contains both code and libs. No Lambda Layer needed.
  - `staging/cicd/lambda-slack-notifier/variables.tf:1` — sets `lambda_handler` (default `slack_notifier.lambda_handler`), runtime, and expects `slack_webhook_url`.
- Runtime:
  - Python 3.9 by default (`lambda_runtime` var). Update as needed.
- Environment variables in Lambda:
  - `SLACK_WEBHOOK_URL` is set from a sensitive TF var (see `terraform.tfvars`).
  - `ENVIRONMENT` is set (staging in this module), used in Slack footer context.
  - `LOG_LEVEL` controls verbosity.

What the handler does (high level):

- Parses SNS event wrapper, then the inner CodeStar message (JSON).
- Routes by source/type: CodePipeline, CodeBuild, or Approval events.
- Builds a markdown message with emojis and console deep links.
- Posts to Slack via `requests.post(webhook_url, json_payload)`.

Key functions in code:

- CodePipeline formatting: `format_codepipeline_message(...)` in `staging/cicd/lambda-slack-notifier/src/slack_notifier.py:16`
- CodeBuild formatting: `format_codebuild_message(...)` in `staging/cicd/lambda-slack-notifier/src/slack_notifier.py:35`
- Manual Approval formatting: `format_approval_message(...)` in `staging/cicd/lambda-slack-notifier/src/slack_notifier.py:55`
- Dispatcher: `format_message_from_event(...)` in `staging/cicd/lambda-slack-notifier/src/slack_notifier.py:125`
- Entry point: `lambda_handler(event, context)` in `staging/cicd/lambda-slack-notifier/src/slack_notifier.py:188`

Resilience:

- CloudWatch Logs group: `staging/cicd/lambda-slack-notifier/cloudwatch.tf:1`
- SQS DLQ wired via `dead_letter_config`: `staging/cicd/lambda-slack-notifier/sqs.tf:1`
- IAM: basic execution + permission to send to DLQ: `staging/cicd/lambda-slack-notifier/iam.tf:1`

## Lambda (Python) Deep Dive

What it is: A small, single‑file Python app that turns AWS build/pipeline events into readable Slack messages.

How it starts: AWS invokes `slack_notifier.lambda_handler(event, context)`.

How it decides what to say (routing logic):

- If the event comes from SNS, it unwraps `event['Records'][0]['Sns']['Message']` and parses the inner JSON.
- It checks `source` and `detailType` to choose a formatter:
  - `aws.codepipeline` → `format_codepipeline_message`
  - `aws.codebuild` → `format_codebuild_message`
  - Manual approvals (detailType contains “Action Execution State Change” + stage = Approval) → `format_approval_message`
- If it can’t classify, it sends a generic dump to help diagnose.

How it formats (high level):

- CodePipeline: shows pipeline name, execution id, state, optional stage/action, plus a deep link to the execution timeline.
- CodeBuild: shows project, short build id, state, and a deep link to the build.
- Approvals: shows pipeline/stage/action and whether approval is needed/approved/rejected. Includes comments/approver if present, with a link to the pipeline view.
- All messages append a context line with environment and timestamp.

How it talks to Slack:

- Reads `SLACK_WEBHOOK_URL` from env vars, or optionally fetches from SSM (`SLACK_WEBHOOK_URL_SSM_PARAM`).
- Uses a shared `requests.Session()` and `json=` to POST the Blocks payload to the webhook.
- Handles `429` rate limits with short backoff; logs request/response for troubleshooting.

Configuration used by the code:

- `SLACK_WEBHOOK_URL` (required): your Incoming Webhook URL (do not commit this).
- `ENVIRONMENT` (optional): shown in the footer (e.g., staging, prod).
- `LOG_LEVEL` (optional): INFO by default.

Dependencies and packaging:

- Python dependencies (`requests` and transitive deps) are vendored under `src/` so the `archive_file` zip contains both code and libs. This avoids layers and keeps deploys simple.
- Update or add deps by editing `src/requirements.txt` and vendoring them into `src/` before applying (current tree already includes the site‑packages).

Errors and retries:

- Slack 4xx responses are logged and returned as 500; SNS/Lambda may retry transient errors.
- Implement a small backoff on `429 Too Many Requests`; keep messages concise to avoid Slack block limits.
- A DLQ is configured; repeated failures land in SQS for later inspection.

Extending the formatter (examples):

- Mentions on failure: append `@devops` when state == FAILED.
- Per‑pipeline routing: add logic to branch by `pipeline` and use a different webhook per environment.
- Extra context: include commit SHA or artifact info if present in the event’s `detail`.

## Key Code Excerpts

Python — trimmed for clarity (full source lives at `staging/cicd/lambda-slack-notifier/src/slack_notifier.py`).

Handler (entry point):

```python
import json, os, time, logging, requests, boto3
from datetime import datetime

session = requests.Session()

def _get_webhook():
    name = os.environ.get('SLACK_WEBHOOK_URL_SSM_PARAM')
    if name:
        ssm = boto3.client('ssm')
        p = ssm.get_parameter(Name=name, WithDecryption=True)
        return p['Parameter']['Value']
    return os.environ.get('SLACK_WEBHOOK_URL')

SLACK_WEBHOOK_URL = _get_webhook()
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'unknown')
logger = logging.getLogger()
logger.setLevel(os.environ.get('LOG_LEVEL', 'INFO').upper())

def _post_to_slack(payload):
    for attempt in range(3):
        resp = session.post(SLACK_WEBHOOK_URL, json=payload, timeout=10)
        if resp.status_code == 429:
            time.sleep(min(int(resp.headers.get('Retry-After', '1')), 5))
            continue
        resp.raise_for_status()
        return
    resp.raise_for_status()

def lambda_handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}")

    if not SLACK_WEBHOOK_URL:
        logger.error("Slack Webhook URL is not configured.")
        return {"statusCode": 500, "body": json.dumps({"message": "Missing webhook"})}

    try:
        message_text = format_message_from_event(event)
        timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")

        slack_payload = {
            "blocks": [
                {"type": "section", "text": {"type": "mrkdwn", "text": message_text}},
                {"type": "context", "elements": [
                    {"type": "mrkdwn", "text": f"*Environment*: {ENVIRONMENT} | *Timestamp*: {timestamp}"}
                ]}
            ]
        }

        _post_to_slack(slack_payload)
        return {"statusCode": 200, "body": json.dumps({"message": "ok"})}
    except Exception as e:
        logger.error(f"Notify error: {e}", exc_info=True)
        return {"statusCode": 500, "body": json.dumps({"message": str(e)})}
```

Formatter (CodePipeline):

```python
def format_codepipeline_message(detail, region):
    pipeline_name = detail.get('pipeline', 'N/A')
    execution_id = detail.get('execution-id', 'N/A')
    state = detail.get('state', 'N/A')
    stage = detail.get('stage', '')
    action = detail.get('action', '')

    icon = ":white_check_mark:" if state == "SUCCEEDED" else \
           ":x:" if state == "FAILED" else \
           ":rocket:" if state == "STARTED" else \
           ":information_source:"

    msg = f"{icon} *Pipeline*: {pipeline_name}\n*Execution ID*: {execution_id}\n*Status*: {state}"
    if stage:  msg += f"\n*Stage*: {stage}"
    if action: msg += f"\n*Action*: {action}"
    msg += (f"\n<https://{region}.console.aws.amazon.com/codesuite/codepipeline/"
            f"pipelines/{pipeline_name}/executions/{execution_id}/timeline?region={region}|View in Console>")
    return msg
```

Note: The router `format_message_from_event(...)` picks the correct formatter based on `source`/`detailType` and unwraps SNS events. See the source file for the full routing logic if you need to extend it.

Router (event classification skeleton):

````python
def format_message_from_event(event):
    # Default to generic dump so unknown events still show up in Slack
    msg = f"Received event:\n```\n{json.dumps(event, indent=2)}\n```"

    # SNS wrapper → inner CodeStar JSON
    if 'Records' in event and event['Records'] and 'Sns' in event['Records'][0]:
        inner = json.loads(event['Records'][0]['Sns'].get('Message', '{}'))
        source = inner.get('source')
        detail_type = inner.get('detailType', '')
        detail = inner.get('detail', {})
    else:
        source = event.get('source')
        detail_type = event.get('detailType', '')
        detail = event.get('detail', {})

    if detail_type == 'CodePipeline Action Execution State Change' and detail.get('stage') == 'Approval':
        return format_approval_message(detail)
    if source == 'aws.codepipeline':
        return format_codepipeline_message(detail, os.environ.get('AWS_REGION', 'us-east-1'))
    if source == 'aws.codebuild' or 'CodeBuild' in detail_type:
        return format_codebuild_message(detail, os.environ.get('AWS_REGION', 'us-east-1'))
    return msg
````

Terraform packaging (minimal example):

```hcl
terraform {
  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.4" }
  }
}

variable "slack_webhook_url" { type = string; sensitive = true }

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"    # contains slack_notifier.py and vendored deps
  output_path = "${path.module}/lambda_payload.zip"
}

resource "aws_iam_role" "lambda_exec" {
  name               = "loftwah-slack-notifier-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "slack_notifier" {
  function_name    = "loftwah-slack-notifier"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "slack_notifier.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30
  memory_size      = 128
  environment { variables = { SLACK_WEBHOOK_URL = var.slack_webhook_url, LOG_LEVEL = "INFO", ENVIRONMENT = "staging" } }
}
```

SNS + CodeStar Notifications (minimal example):

```hcl
resource "aws_sns_topic" "build_notifications" { name = "loftwah-build-notifications-staging" }

resource "aws_sns_topic_policy" "allow_codestar" {
  arn    = aws_sns_topic.build_notifications.arn
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid = "AllowCodeStarNotifications",
      Effect = "Allow",
      Principal = { Service = "codestar-notifications.amazonaws.com" },
      Action = "sns:Publish",
      Resource = aws_sns_topic.build_notifications.arn,
      Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } }
    }]
  })
}

data "aws_caller_identity" "current" {}
resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.build_notifications.arn
}

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.build_notifications.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notifier.arn

  # Optional filter to reduce noise and Lambda invocations
  filter_policy       = jsonencode({ state = ["FAILED", "SUCCEEDED"] })
  filter_policy_scope = "MessageBody"
}

# Point CodeStar Notifications for a pipeline at the SNS topic
resource "aws_codestarnotifications_notification_rule" "pipeline" {
  name          = "loftwah-pipeline-notify"
  resource      = aws_codepipeline.main.arn
  detail_type   = "FULL"
  event_type_ids = [
    "codepipeline-pipeline-pipeline-execution-succeeded",
    "codepipeline-pipeline-pipeline-execution-failed",
    "codepipeline-pipeline-pipeline-execution-started"
  ]
  target { type = "SNS", address = aws_sns_topic.build_notifications.arn }
}
```

## Integration with CodePipeline

- Event source is the pipeline itself; no pipeline spec change required for notifications.
- Granularity: Target pipeline/stage/action events by adjusting event types in the rule.
- Correlation: Include `executionId` in Slack message to line up with console links.
- Multi‑pipeline: Use one SNS topic per pipeline or a shared topic; tag messages with pipeline name in Lambda.

Repo specifics (staging):

- SNS topics are defined per app (e.g., Web/Clicks/Connect Client) and named like `classtag-<app>-build-notifications-staging`. See each `sns.tf` under `staging/cicd/<app>/`.
- The topic policy permits CodeStar Notifications to publish.
- Each `sns.tf` subscribes the shared Slack Lambda via:
  - `aws_lambda_permission` allowing `sns.amazonaws.com` from that topic ARN.
  - `aws_sns_topic_subscription` with `protocol = "lambda"` and `endpoint = <lambda_arn>`.
- Notification rules live alongside each pipeline/build config (`codepipeline.tf` / `codebuild.tf`). They point at the app’s SNS topic and select event types (failed/succeeded/started).

### Optional: SNS Filter Policies

- Apply an SNS filter policy on the Lambda subscription to invoke only for certain states (e.g., `FAILED`, `SUCCEEDED`) or specific pipelines.
- Use `filter_policy_scope = "MessageBody"` to match on fields from the CodeStar message body (for example, `detail.state`).

## Rebuild Checklist

1. Create Slack app (Loftwah workspace) with Incoming Webhooks and generate the webhook URL.
2. Store webhook in SSM SecureString: `/<env>/loftwah/slack/webhook_url` (optionally encrypt with a CMK).
3. Provision Lambda:
   - Execution role with Logs + SSM (+ KMS if needed).
   - Env vars for parameter names and defaults (channel, username, emoji).
   - Deploy code that parses CodeStar event detail and posts to Slack.
4. Create SNS topic and policy to allow CodeStar Notifications to publish.
5. Subscribe Lambda to SNS (protocol `lambda`), add `aws_lambda_permission` for `sns.amazonaws.com`.
6. Add CodeStar notification rules:
   - For the pipeline: success/failure (and started if desired) → target the SNS topic.
   - Optionally add rules for CodeBuild projects.
7. Validate end‑to‑end:
   - Trigger a no‑op pipeline run.
   - Check Lambda logs for delivery and confirm Slack messages.
8. Tighten security:
   - Restrict SSM IAM to exact parameters.
   - If using a CMK, limit `kms:Decrypt` to the Lambda role.
   - Apply least privilege on the SNS topic policy.

Repo‑specific rebuild steps (staging):

- Deploy the Lambda first in `staging/cicd/lambda-slack-notifier/`:
  - Set `slack_webhook_url` in `terraform.tfvars` (or switch to SSM).
  - `terraform init && terraform apply` to create the function and DLQ/logs.
  - Capture outputs: `lambda_function_arn`, `lambda_function_name`.
- Wire the Lambda into each app:
  - In `staging/cicd/<app>/sns.tf`, set the `slack_notifier_lambda_arn` and `slack_notifier_lambda_function_name` variables to the outputs above (they are exposed as inputs in each app’s `variables.tf`).
  - `terraform apply` in each app’s folder to update SNS subscription + permission.
- Ensure CodeStar notification rules exist in each app’s `codebuild.tf` / `codepipeline.tf` and point to that app’s SNS topic.

## Runbook (Deploy, Update, Test, Rollback)

- First‑time deploy (staging):
  - In `staging/cicd/lambda-slack-notifier/`, set `slack_webhook_url` in `terraform.tfvars` (or reference an SSM param if migrating to SSM).
  - Run: `terraform init && terraform apply`.
  - Capture outputs: `lambda_function_arn`, `lambda_function_name`.
  - In each `staging/cicd/<app>/`, provide those two values (via TF var mechanism) and `terraform apply` to create the subscription + permission.

- Updating code:
  - Edit `src/slack_notifier.py` (and any deps under `src/`).
  - Re‑apply: `terraform apply` in `staging/cicd/lambda-slack-notifier/` (the archive hash changes and Lambda updates).

- Testing:
  - Console test: Use sample payloads in `staging/cicd/lambda-slack-notifier/test/*.json` from the Lambda Console’s “Test” tab.
  - End‑to‑end: Manually release a pipeline; watch CloudWatch logs and Slack channel.

- Rollback:
  - If a change breaks messages, re‑apply the previous working commit (Terraform will republish the prior zip).

## Security Notes

- Do not commit real webhook URLs. Prefer SSM SecureString and grant `ssm:GetParameter` to the Lambda role, or pass the value via a secure CI/CD variable store. If a webhook leaks, rotate it in Slack immediately.
- Least privilege on SNS topic policies: scope `sns:Publish` to the exact CodeStar Notifications service principal and your account.
- Principle of least privilege for Lambda role: limit SSM/KMS permissions to specific parameters/keys if you adopt SSM.
- Logs may include event summaries and Slack responses; ensure log retention is appropriate for your environment.
- If the SNS topic is KMS‑encrypted, update the KMS key policy to allow CodeStar Notifications to publish and Lambda to read (principal `codestar-notifications.amazonaws.com` and your account).

## Operations and Troubleshooting

- No Slack message:
  - Ensure the CodeStar Notifications rule is Active.
  - Verify SNS metrics (NumberOfMessagesPublished) and Lambda invocations.
  - Inspect Lambda CloudWatch logs for Slack HTTP response codes.
- Repeated failures:
  - Slack 4xx indicates payload issues; log payload and reason.
  - Consider a Lambda DLQ and alerting via CloudWatch Alarm.
  - `429 Too Many Requests`: Slack is rate‑limiting; the handler’s short backoff helps. Consider SNS filter policies or batching to reduce message volume.
- Rotating secrets:
  - Update SSM SecureString; no Lambda redeploy needed if it reads per‑invocation or on cache expiry.
  - If using TF var for the webhook URL, rotate the value out‑of‑band and re‑apply (do not commit secrets).

## Notes and Alternatives

- Rationale: Flexible Slack logic (formatting, routing, mentions) independent of AWS Chatbot.
- Alternative: AWS Chatbot + Slack channel configuration (not used here by design).
- Extensibility: Per‑pipeline channel routing, environment badges (dev/test/prod), Git metadata when available.

## Quick FAQ

- Where does it happen? In AWS: CodeStar Notifications publish to an SNS topic. That topic invokes the Lambda function you deployed (Python code in this repo). Lambda posts to Slack.
- Where is the code? `staging/cicd/lambda-slack-notifier/src/slack_notifier.py:1` (plus vendored libs in the same folder).
- How does the Python become a Lambda? Terraform uses `archive_file` to zip the `src/` folder and uploads it as the Lambda package (`aws_lambda_function.filename` points to the zip).
- How does CodePipeline connect to the Lambda? Through CodeStar Notification Rules → SNS topic (per app) → SNS subscription to the Lambda (permission + subscription in each app’s `sns.tf`).
- How do I test it? Use the JSON samples in `staging/cicd/lambda-slack-notifier/test/` in the Lambda Console’s Test tab, or trigger a pipeline run and watch CloudWatch logs.

## Drop‑In Terraform Module (Based on Prod Pattern)

Goal: a self‑contained module you can reuse in any account/environment. It packages the Python, deploys the Lambda, creates an SNS topic, wires permissions/subscription, and attaches CodeStar Notification Rules to pipelines and/or CodeBuild projects you pass in.

Module layout (copy into a folder, e.g., `modules/slack_notifier/`):

`variables.tf`

```hcl
variable "env" { description = "Environment label" type = string }
variable "slack_webhook_url" { description = "Slack Incoming Webhook URL" type = string sensitive = true }
variable "pipeline_arns" { description = "CodePipeline ARNs" type = list(string) default = [] }
variable "codebuild_project_arns" { description = "CodeBuild project ARNs" type = list(string) default = [] }
variable "function_name" { description = "Lambda name" type = string default = null }
variable "runtime" { description = "Lambda runtime" type = string default = "python3.11" }
variable "log_level" { description = "Lambda log level" type = string default = "INFO" }
variable "tags" { description = "Tags for all resources" type = map(string) default = {} }
```

`main.tf`

```hcl
locals {
  lambda_name = coalesce(var.function_name, "loftwah-slack-notifier-${var.env}")
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"     # include slack_notifier.py + vendored deps
  output_path = "${path.module}/lambda_payload.zip"
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${local.lambda_name}-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "lambda.amazonaws.com" } }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.lambda_name}"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_lambda_function" "notifier" {
  function_name    = local.lambda_name
  role             = aws_iam_role.lambda_exec.arn
  handler          = "slack_notifier.lambda_handler"
  runtime          = var.runtime
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30
  memory_size      = 128
  environment { variables = { SLACK_WEBHOOK_URL = var.slack_webhook_url, LOG_LEVEL = var.log_level, ENVIRONMENT = var.env } }
  depends_on = [aws_cloudwatch_log_group.lambda]
  tags       = var.tags
}

resource "aws_sqs_queue" "dlq" {
  name                   = "${local.lambda_name}-dlq"
  sqs_managed_sse_enabled = true
  tags                   = var.tags
}

resource "aws_lambda_function_event_invoke_config" "notifier" {
  function_name                = aws_lambda_function.notifier.arn
  maximum_retry_attempts       = 2
  destination_config { on_failure { destination = aws_sqs_queue.dlq.arn } }
}

resource "aws_sns_topic" "build_notifications" {
  name = "loftwah-build-notifications-${var.env}"
  tags = var.tags
}

resource "aws_sns_topic_policy" "allow_codestar" {
  arn    = aws_sns_topic.build_notifications.arn
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "AllowCodeStarNotifications",
      Effect    = "Allow",
      Principal = { Service = "codestar-notifications.amazonaws.com" },
      Action    = "sns:Publish",
      Resource  = aws_sns_topic.build_notifications.arn
    }]
  })
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.build_notifications.arn
}

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.build_notifications.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.notifier.arn
}

# One rule per pipeline ARN
resource "aws_codestarnotifications_notification_rule" "pipeline" {
  for_each     = toset(var.pipeline_arns)
  name         = "loftwah-${var.env}-${replace(each.value, ":", "-")}-pipeline"
  detail_type  = "FULL"
  resource     = each.value
  event_type_ids = [
    "codepipeline-pipeline-pipeline-execution-started",
    "codepipeline-pipeline-pipeline-execution-succeeded",
    "codepipeline-pipeline-pipeline-execution-failed"
  ]
  target { type = "SNS", address = aws_sns_topic.build_notifications.arn }
}

# One rule per CodeBuild project ARN
resource "aws_codestarnotifications_notification_rule" "codebuild" {
  for_each     = toset(var.codebuild_project_arns)
  name         = "loftwah-${var.env}-${replace(each.value, ":", "-")}-codebuild"
  detail_type  = "FULL"
  resource     = each.value
  event_type_ids = [
    "codebuild-project-build-state-in-progress",
    "codebuild-project-build-state-succeeded",
    "codebuild-project-build-state-failed",
    "codebuild-project-build-state-stopped"
  ]
  target { type = "SNS", address = aws_sns_topic.build_notifications.arn }
}
```

`outputs.tf`

```hcl
output "lambda_function_arn" { value = aws_lambda_function.notifier.arn }
output "lambda_function_name" { value = aws_lambda_function.notifier.function_name }
output "sns_topic_arn" { value = aws_sns_topic.build_notifications.arn }
```

`src/slack_notifier.py` (copy from the excerpts above; include vendored deps or a tiny `requirements.txt` and vendor before apply).

Usage example (root stack):

```hcl
module "slack_notify" {
  source               = "./modules/slack_notifier"
  env                  = "staging"
  slack_webhook_url    = var.slack_webhook_url   # pass securely via TF var/TF Cloud
  pipeline_arns        = [aws_codepipeline.app.arn]
  codebuild_project_arns = [aws_codebuild_project.app.arn]
  tags = { Environment = "staging", Owner = "Loftwah" }
}
```

Notes:

- Keep the webhook URL out of source control; use TF Cloud/Workspaces, a `.auto.tfvars` in a secure place, or migrate to SSM SecureString and update the Lambda to read from SSM if preferred.
- If you already have per‑app SNS topics in prod, you can remove the topic from this module and instead pass in the topic ARN and subscribe the Lambda there — the Lambda function is reusable across topics.

## Dependencies and Vendoring (So They’re In The Zip)

Goal: Ensure Python packages are inside the `src/` folder before Terraform zips it — so the Lambda runtime can import them.

Minimal requirements file (example):

```text
# src/requirements.txt
requests==2.32.3
```

Quick local vendoring (pure-Python deps like requests — safe on macOS/Linux):

```bash
cd modules/slack_notifier   # or staging/cicd/lambda-slack-notifier

# Optionally use a virtualenv just for tooling isolation
python3 -m venv .venv && source .venv/bin/activate
python -m pip install --upgrade pip

# Install third-party deps directly into the lambda src/ folder
pip install -r src/requirements.txt -t src/

# Verify site-packages are present
ls -1 src | grep -E 'requests|urllib3|certifi|idna|charset_normalizer'

# Then package/deploy with Terraform
terraform init && terraform apply
```

Build in a Linux container (for compiled/native deps):

- Not required for `requests` (pure Python), but if you add packages with native extensions, build on Amazon Linux to match the Lambda runtime.

```bash
cd modules/slack_notifier
docker run --rm -v "$PWD/src":/var/task python:3.11-slim \
  sh -c "python -m pip install --upgrade pip && pip install -r /var/task/requirements.txt -t /var/task"

terraform apply
```

Tips:

- Keep `slack_notifier.py` directly under `src/` so the handler `slack_notifier.lambda_handler` works.
- Do not exclude `.dist-info` folders from the zip — they’re fine to include.
- To refresh deps, delete previous vendored folders in `src/` (e.g., `requests*`, `urllib3*`, etc.) and re-run the pip install step.
