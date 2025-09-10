data "aws_caller_identity" "current" {}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "tf-state-139294524816-us-east-1"
    key    = "staging/network/terraform.tfstate"
    region = "us-east-1"
    profile = "devops-sandbox"
  }
}

locals {
  vpc_id             = data.terraform_remote_state.vpc.outputs.vpc_id
  public_subnet_ids  = data.terraform_remote_state.vpc.outputs.public_subnet_ids
  private_subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = 14
  tags              = merge(var.tags, { Name = "${var.app_name}-logs" })
}

resource "aws_security_group" "alb" {
  name   = "${var.app_name}-alb"
  vpc_id = local.vpc_id

  ingress { from_port = 80 to_port = 80 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0  to_port = 0  protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }

  tags = merge(var.tags, { Name = "${var.app_name}-alb" })
}

resource "aws_security_group" "service" {
  name   = "${var.app_name}-svc"
  vpc_id = local.vpc_id

  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }

  tags = merge(var.tags, { Name = "${var.app_name}-svc" })
}

resource "aws_lb" "this" {
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = local.public_subnet_ids
  tags               = merge(var.tags, { Name = "${var.app_name}-alb" })
}

resource "aws_lb_target_group" "this" {
  name        = "${var.app_name}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    path                = var.healthcheck_path
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200-399"
  }

  tags = merge(var.tags, { Name = "${var.app_name}-tg" })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_iam_role" "task_execution" {
  name               = "${var.app_name}-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }
    ]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "exec_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  ])
  role       = aws_iam_role.task_execution.name
  policy_arn = each.value
}

resource "aws_iam_role" "task" {
  name               = "${var.app_name}-task"
  assume_role_policy = aws_iam_role.task_execution.assume_role_policy
  tags               = var.tags
}

data "aws_iam_policy_document" "task_inline" {
  statement {
    sid     = "SSMRead"
    actions = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = [
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/devops-refresher/staging/*"
    ]
  }
  statement {
    sid     = "S3ReadWrite"
    actions = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
    resources = [
      "arn:aws:s3:::${var.s3_bucket_name}",
      "arn:aws:s3:::${var.s3_bucket_name}/app/*"
    ]
  }
}

resource "aws_iam_role_policy" "task_inline" {
  name   = "${var.app_name}-task-perms"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_inline.json
}

resource "aws_ecr_repository" "app" {
  name                 = var.app_name
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  tags = merge(var.tags, { Name = var.app_name })
}

resource "aws_ecs_cluster" "this" {
  name = "${var.app_name}-cluster"
  setting { name = "containerInsights" value = "enabled" }
  tags = var.tags
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.app_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
      essential = true
      portMappings = [{ containerPort = var.app_port, protocol = "tcp" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "app"
        }
      }
      environment = [
        { name = "APP_ENV", value = "staging" },
        { name = "S3_BUCKET", value = var.s3_bucket_name }
      ]
    }
  ])
  tags = var.tags
}

resource "aws_ecs_service" "app" {
  name            = "${var.app_name}"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = local.private_subnet_ids
    security_groups = [aws_security_group.service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "app"
    container_port   = var.app_port
  }

  depends_on = [aws_lb_listener.http]
  tags       = var.tags
}

output "ecs_alb_dns_name" { value = aws_lb.this.dns_name }
output "ecs_cluster_name" { value = aws_ecs_cluster.this.name }
output "ecs_service_name" { value = aws_ecs_service.app.name }
output "ecr_repository_url" { value = aws_ecr_repository.app.repository_url }

