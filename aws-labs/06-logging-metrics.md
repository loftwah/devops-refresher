# Lab 06: Logging and Metrics

## Objectives

- Ensure logs and basic metrics/alarms are in place for the ECS service.

## Tasks

1. CloudWatch log group per service with retention.
2. Dashboards for ALB 5XX, Target 5XX, ECS CPU/Memory.
3. Alarms: ALB 5XX spike, ECS CPU > 70% sustained.

## Acceptance Criteria

- Logs visible in CloudWatch; dashboards render metrics; alarms can be tested and recover.

## Hints

- Use `aws cloudwatch put-metric-alarm` in Terraform via `aws_cloudwatch_metric_alarm`.
- SNS topic for notifications; optional Slack/Lambda bridge.
