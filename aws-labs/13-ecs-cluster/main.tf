resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/aws/ecs/devops-refresher-staging"
  retention_in_days = 30
}

resource "aws_ecs_cluster" "this" {
  name = "devops-refresher-staging"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

output "cluster_name" { value = aws_ecs_cluster.this.name }
output "cluster_arn" { value = aws_ecs_cluster.this.arn }
output "log_group_name" { value = aws_cloudwatch_log_group.ecs.name }

