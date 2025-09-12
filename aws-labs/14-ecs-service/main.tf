data "terraform_remote_state" "cluster" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/ecs-cluster/terraform.tfstate"
    region       = "us-east-1"
    profile      = "devops-sandbox"
    use_lockfile = true
    encrypt      = true
  }
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/network/terraform.tfstate"
    region       = "us-east-1"
    profile      = "devops-sandbox"
    use_lockfile = true
    encrypt      = true
  }
}

data "terraform_remote_state" "sg" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/security-groups/terraform.tfstate"
    region       = "us-east-1"
    profile      = "devops-sandbox"
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
    profile      = "devops-sandbox"
    use_lockfile = true
    encrypt      = true
  }
}

data "terraform_remote_state" "iam" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/iam/terraform.tfstate"
    region       = "us-east-1"
    profile      = "devops-sandbox"
    use_lockfile = true
    encrypt      = true
  }
}

data "terraform_remote_state" "ecr" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/ecr/terraform.tfstate"
    region       = "us-east-1"
    profile      = "devops-sandbox"
    use_lockfile = true
    encrypt      = true
  }
}

locals {
  container_name             = var.service_name
  cluster_arn_effective      = length(var.cluster_arn) > 0 ? var.cluster_arn : data.terraform_remote_state.cluster.outputs.cluster_arn
  subnet_ids_effective       = length(var.subnet_ids) > 0 ? var.subnet_ids : data.terraform_remote_state.vpc.outputs.private_subnet_ids
  sg_ids_effective           = length(var.security_group_ids) > 0 ? var.security_group_ids : [data.terraform_remote_state.sg.outputs.app_sg_id]
  target_group_arn_effective = length(var.target_group_arn) > 0 ? var.target_group_arn : data.terraform_remote_state.alb.outputs.tg_arn
  exec_role_arn_effective    = length(var.execution_role_arn) > 0 ? var.execution_role_arn : data.terraform_remote_state.iam.outputs.execution_role_arn
  task_role_arn_effective    = length(var.task_role_arn) > 0 ? var.task_role_arn : data.terraform_remote_state.iam.outputs.task_role_arn
  image_effective            = length(var.image) > 0 ? var.image : "${data.terraform_remote_state.ecr.outputs.repository_url}:staging"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.service_name}-staging"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = local.exec_role_arn_effective
  task_role_arn            = local.task_role_arn_effective

  container_definitions = jsonencode([
    {
      name         = local.container_name,
      image        = local.image_effective,
      essential    = true,
      portMappings = [{ containerPort = var.container_port, hostPort = var.container_port, protocol = "tcp" }],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = var.log_group_name,
          awslogs-region        = var.region,
          awslogs-stream-prefix = var.service_name
        }
      },
      secrets     = var.secrets,
      environment = var.environment
    }
  ])
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}

resource "aws_ecs_service" "app" {
  name            = var.service_name
  cluster         = local.cluster_arn_effective
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  propagate_tags  = "TASK_DEFINITION"
  enable_execute_command = var.enable_execute_command

  network_configuration {
    subnets          = local.subnet_ids_effective
    security_groups  = local.sg_ids_effective
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = local.target_group_arn_effective
    container_name   = local.container_name
    container_port   = var.container_port
  }

  lifecycle { ignore_changes = [task_definition] }
}

output "service_name" { value = aws_ecs_service.app.name }
output "task_definition_arn" { value = aws_ecs_task_definition.app.arn }
