#############################
# Remote State Lookups
#############################

data "terraform_remote_state" "cluster" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/ecs-cluster/terraform.tfstate"
    region       = "us-east-1"
    profile      = var.aws_profile
    use_lockfile = true
    encrypt      = true
  }
}

data "terraform_remote_state" "service" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/ecs-service/terraform.tfstate"
    region       = "us-east-1"
    profile      = var.aws_profile
    use_lockfile = true
    encrypt      = true
  }
}

data "terraform_remote_state" "alb" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/alb/terraform.tfstate"
    region       = "us-east-1"
    profile      = var.aws_profile
    use_lockfile = true
    encrypt      = true
  }
}

data "terraform_remote_state" "rds" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/rds/terraform.tfstate"
    region       = "us-east-1"
    profile      = var.aws_profile
    use_lockfile = true
    encrypt      = true
  }
}

data "terraform_remote_state" "redis" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/redis/terraform.tfstate"
    region       = "us-east-1"
    profile      = var.aws_profile
    use_lockfile = true
    encrypt      = true
  }
}

locals {
  cluster_name  = data.terraform_remote_state.cluster.outputs.cluster_name
  service_name  = try(data.terraform_remote_state.service.outputs.service_name, var.service_name)
  ecs_log_group = try(data.terraform_remote_state.cluster.outputs.log_group_name, "/aws/ecs/devops-refresher-${var.env}")

  # ALB/TG data sources from ARNs
  alb_arn = data.terraform_remote_state.alb.outputs.alb_arn
  tg_arn  = data.terraform_remote_state.alb.outputs.tg_arn
}

data "aws_lb" "alb" {
  arn = local.alb_arn
}

data "aws_lb_target_group" "tg" {
  arn = local.tg_arn
}

#############################
# SNS for Alerts
#############################

resource "aws_sns_topic" "alerts" {
  name         = "devops-refresher-${var.env}-alerts"
  display_name = "devops-refresher ${var.env} Alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "sns_policy" {
  statement {
    sid     = "AllowCloudWatchPublish"
    effect  = "Allow"
    actions = ["sns:Publish"]
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
    resources = [aws_sns_topic.alerts.arn]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "this" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.sns_policy.json
}

#############################
# CloudWatch Alarms: ECS
#############################

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.env}-${local.service_name}-ecs-cpu-high"
  alarm_description   = "ECS service CPU >= 80%"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  period              = 300
  threshold           = 80
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  statistic           = "Average"
  dimensions = {
    ClusterName = local.cluster_name
    ServiceName = local.service_name
  }
  treat_missing_data = "notBreaching"
  alarm_actions      = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${var.env}-${local.service_name}-ecs-memory-high"
  alarm_description   = "ECS service Memory >= 80%"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  period              = 300
  threshold           = 80
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  statistic           = "Average"
  dimensions = {
    ClusterName = local.cluster_name
    ServiceName = local.service_name
  }
  treat_missing_data = "notBreaching"
  alarm_actions      = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
}

#############################
# CloudWatch Alarms: ALB & TG
#############################

resource "aws_cloudwatch_metric_alarm" "alb_5xx_elb" {
  alarm_name          = "${var.env}-alb-elb-5xx"
  alarm_description   = "ALB 5XX at the load balancer > 5 in 5m"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  period              = 300
  threshold           = 5
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  statistic           = "Sum"
  dimensions = {
    LoadBalancer = data.aws_lb.alb.arn_suffix
  }
  treat_missing_data = "notBreaching"
  alarm_actions      = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_target" {
  alarm_name          = "${var.env}-alb-target-5xx"
  alarm_description   = "ALB target 5XX > 5 in 5m"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  period              = 300
  threshold           = 5
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  statistic           = "Sum"
  dimensions = {
    LoadBalancer = data.aws_lb.alb.arn_suffix
    TargetGroup  = data.aws_lb_target_group.tg.arn_suffix
  }
  treat_missing_data = "notBreaching"
  alarm_actions      = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_latency_p95" {
  alarm_name          = "${var.env}-alb-latency-p95"
  alarm_description   = "ALB TargetResponseTime p95 > 1.5s"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  period              = 300
  threshold           = 1.5
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  extended_statistic  = "p95"
  dimensions = {
    LoadBalancer = data.aws_lb.alb.arn_suffix
  }
  treat_missing_data = "notBreaching"
  alarm_actions      = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "tg_unhealthy_hosts" {
  alarm_name          = "${var.env}-tg-unhealthy-hosts"
  alarm_description   = "ALB Target Group has unhealthy hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  period              = 60
  threshold           = 0
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  statistic           = "Average"
  dimensions = {
    LoadBalancer = data.aws_lb.alb.arn_suffix
    TargetGroup  = data.aws_lb_target_group.tg.arn_suffix
  }
  treat_missing_data = "notBreaching"
  alarm_actions      = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
}

#############################
# CloudWatch Alarms: RDS
#############################

locals {
  rds_identifier             = "${var.env}-${var.service_name}-postgres"
  rds_free_storage_threshold = 2 * 1024 * 1024 * 1024 # 2 GiB
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${local.rds_identifier}-cpu-high"
  alarm_description   = "RDS CPU >= 80%"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  period              = 300
  threshold           = 80
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  statistic           = "Average"
  dimensions = {
    DBInstanceIdentifier = local.rds_identifier
  }
  treat_missing_data = "notBreaching"
  alarm_actions      = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage_low" {
  alarm_name          = "${local.rds_identifier}-free-storage-low"
  alarm_description   = "RDS FreeStorageSpace < 2 GiB"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  period              = 300
  threshold           = local.rds_free_storage_threshold
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  statistic           = "Average"
  dimensions = {
    DBInstanceIdentifier = local.rds_identifier
  }
  treat_missing_data = "notBreaching"
  alarm_actions      = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_freeable_memory_low" {
  alarm_name          = "${local.rds_identifier}-freeable-memory-low"
  alarm_description   = "RDS FreeableMemory < 100 MiB"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  period              = 300
  threshold           = 104857600 # 100 MiB
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  statistic           = "Average"
  dimensions = {
    DBInstanceIdentifier = local.rds_identifier
  }
  treat_missing_data = "notBreaching"
  alarm_actions      = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
}

#############################
# CloudWatch Alarms: ElastiCache (Redis)
#############################

locals {
  redis_replication_group_id = "${var.env}-${var.service_name}-redis"
}

resource "aws_cloudwatch_metric_alarm" "redis_cpu_high" {
  alarm_name          = "${local.redis_replication_group_id}-cpu-high"
  alarm_description   = "ElastiCache CPU >= 80%"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  period              = 300
  threshold           = 80
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  statistic           = "Average"
  dimensions = {
    ReplicationGroupId = local.redis_replication_group_id
  }
  treat_missing_data = "notBreaching"
  alarm_actions      = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "redis_evictions" {
  alarm_name          = "${local.redis_replication_group_id}-evictions"
  alarm_description   = "ElastiCache Evictions > 0"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  period              = 300
  threshold           = 0
  metric_name         = "Evictions"
  namespace           = "AWS/ElastiCache"
  statistic           = "Sum"
  dimensions = {
    ReplicationGroupId = local.redis_replication_group_id
  }
  treat_missing_data = "notBreaching"
  alarm_actions      = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
}

#############################
# CloudWatch Dashboard
#############################

locals {
  dashboard_name = "devops-refresher-${var.env}"
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = local.dashboard_name

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title = "ECS ${local.service_name} CPU/Memory"
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", local.cluster_name, "ServiceName", local.service_name, { "stat" : "Average" }],
            [".", "MemoryUtilization", ".", ".", ".", ".", { "stat" : "Average" }]
          ]
          period  = 300
          region  = var.region
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title = "ALB Latency p95 & 5XX"
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", data.aws_lb.alb.arn_suffix, { "stat" : "p95" }],
            [".", "HTTPCode_ELB_5XX_Count", ".", ".", { "stat" : "Sum" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { "stat" : "Sum" }]
          ]
          period = 300
          region = var.region
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title = "RDS Health"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", local.rds_identifier, { "stat" : "Average" }],
            [".", "FreeStorageSpace", ".", ".", { "stat" : "Average" }],
            [".", "FreeableMemory", ".", ".", { "stat" : "Average" }]
          ]
          period = 300
          region = var.region
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title = "Redis Health"
          metrics = [
            ["AWS/ElastiCache", "CPUUtilization", "ReplicationGroupId", local.redis_replication_group_id, { "stat" : "Average" }],
            [".", "CurrConnections", ".", ".", { "stat" : "Average" }],
            [".", "Evictions", ".", ".", { "stat" : "Sum" }]
          ]
          period = 300
          region = var.region
        }
      }
    ]
  })
}

#############################
# Log Metric Filter + Alarm: ECS ERRORs
#############################

resource "aws_cloudwatch_log_metric_filter" "ecs_error" {
  name           = "${var.env}-${local.service_name}-ecs-error-filter"
  log_group_name = local.ecs_log_group
  pattern        = "ERROR"

  metric_transformation {
    name      = "EcsErrorCount"
    namespace = "App/Logs"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_log_errors" {
  alarm_name          = "${var.env}-${local.service_name}-ecs-log-errors"
  alarm_description   = "ECS application logs contain ERROR lines (> 0 in 5m)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  period              = 300
  threshold           = 0
  metric_name         = aws_cloudwatch_log_metric_filter.ecs_error.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.ecs_error.metric_transformation[0].namespace
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  depends_on          = [aws_cloudwatch_log_metric_filter.ecs_error]
}
