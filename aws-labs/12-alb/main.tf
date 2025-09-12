// Module behavior overview
// - Inputs are optional and follow precedence: explicit variable > remote state output.
// - This allows fully non-interactive applies when prior labs have been applied
//   (VPC in Lab 01, Security Groups in Lab 07), while still permitting overrides.
// - Fargate compatibility: target group uses target_type = "ip" and health check on /healthz.

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

locals {
  vpc_id_effective            = length(var.vpc_id) > 0 ? var.vpc_id : data.terraform_remote_state.vpc.outputs.vpc_id
  public_subnet_ids_effective = length(var.public_subnet_ids) > 0 ? var.public_subnet_ids : data.terraform_remote_state.vpc.outputs.public_subnet_ids
  alb_sg_id_effective         = length(var.alb_sg_id) > 0 ? var.alb_sg_id : data.terraform_remote_state.sg.outputs.alb_sg_id
  certificate_domain_effective = length(var.certificate_domain_name) > 0 ? var.certificate_domain_name : var.record_name
}

resource "aws_lb" "app" {
  name               = "staging-app-alb"
  load_balancer_type = "application"
  security_groups    = [local.alb_sg_id_effective]
  subnets            = local.public_subnet_ids_effective
}

resource "aws_lb_target_group" "app" {
  name        = "staging-app-tg"
  port        = var.target_port
  protocol    = "HTTP"
  target_type = "ip" # Fargate uses IP targets
  vpc_id      = local.vpc_id_effective

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 15
    timeout             = 5
  }
}

# Route 53 zone lookup
data "aws_route53_zone" "this" {
  name         = var.hosted_zone_name
  private_zone = false
}

# ACM certificate with DNS validation
resource "aws_acm_certificate" "this" {
  domain_name       = local.certificate_domain_effective
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.this.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.value]
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# HTTPS listener using the validated certificate
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.this.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# HTTP listener redirects to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# DNS record pointing to the ALB
resource "aws_route53_record" "app_alias" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.record_name
  type    = "A"

  alias {
    name                   = aws_lb.app.dns_name
    zone_id                = aws_lb.app.zone_id
    evaluate_target_health = true
  }
}
