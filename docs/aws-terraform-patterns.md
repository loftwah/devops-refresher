# AWS Terraform Patterns

Opinionated, end-to-end bundles that group the Terraform resources typically used together, with decisions and gotchas called out.

## ALB + HTTPS + Redirect + DNS

When you need an internet-facing Application Load Balancer that serves HTTPS and redirects HTTP to HTTPS.

Includes:

- `aws_lb` (application), `aws_lb_target_group` (`ip` for Fargate), listeners (80 redirect → 443 forward)
- ACM certificate (DNS validation) and Route53 records
- SGs: ALB SG (80/443 from 0.0.0.0/0), service/task SG (ingress from ALB SG only)

Decisions:

- Domain ownership: Route53 hosted zone vs external DNS
- Certificate issuance: Terraform (`aws_acm_certificate` + validation) vs pre-existing
- HTTP-only vs HTTPS; if HTTPS, redirect strategy and TLS policy

Snippet (HTTPS listener + redirect, cert passed in): see `terraform-resource-cheatsheet.md` ALB Listener section.

Alternate (DNS-validated ACM via Route53):

```terraform
variable "domain_name"        { type = string }
variable "hosted_zone_id"     { type = string }

resource "aws_acm_certificate" "alb" {
  domain_name       = var.domain_name
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation" {
  for_each = { for dvo in aws_acm_certificate.alb.domain_validation_options : dvo.domain_name => dvo }
  zone_id  = var.hosted_zone_id
  name     = each.value.resource_record_name
  type     = each.value.resource_record_type
  records  = [each.value.resource_record_value]
  ttl      = 60
}

resource "aws_acm_certificate_validation" "alb" {
  certificate_arn         = aws_acm_certificate.alb.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}
```

Route53 Alias to ALB:

```terraform
variable "alb_hostname" { type = string } # e.g., app.example.com
variable "hosted_zone_id" { type = string }

resource "aws_route53_record" "alb_alias" {
  zone_id = var.hosted_zone_id
  name    = var.alb_hostname
  type    = "A"
  alias {
    name                   = aws_lb.web.dns_name
    zone_id                = aws_lb.web.zone_id
    evaluate_target_health = true
  }
}
```

Toggle: HTTP-only vs HTTPS + redirect

```terraform
variable "enable_https" { type = bool, default = true }

resource "aws_lb_listener" "https" {
  count             = var.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.web.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.alb.certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = var.enable_https ? "redirect" : "forward"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
    dynamic "forward" {
      for_each = var.enable_https ? [] : [1]
      content {
        target_group {
          arn = aws_lb_target_group.web.arn
        }
      }
    }
  }
}
```

Gotchas:

- ACM cert region must match the ALB region (CloudFront requires us-east-1 certs)
- Target group must be `ip` for Fargate
- Set health check path correctly; 502s usually mean SG/target type issues

## ECS on Fargate (behind ALB)

Typical components:

- VPC with public and private subnets, NAT (per-AZ for prod), endpoints for SSM/Logs/ECR
- SGs: ALB SG (public 80/443), service SG (ingress from ALB SG)
- ECR repo (immutable tags), CloudWatch log group
- IAM: task execution role (pull image, push logs), task role (app AWS access)
- ECS cluster (Container Insights), capacity providers (FARGATE + FARGATE_SPOT)
- Task definition (`awsvpc`, cpu/memory, env/secrets, logs)
- Service (private subnets, no public IPs) with circuit breaker and ALB attachment
- App Auto Scaling target + policies (CPU/memory/ALB request count)

Decisions:

- Service scale range (min/max), rollout safety (circuit breaker), exec access (SSM exec)
- Secrets source (SSM/Secrets Manager), env-by-workspace strategy
- Observability (logs/metrics/alarms) and deployment strategy

Gotchas:

- Use `target_type = "ip"` for TGs; enable health-check grace period
- Keep images immutable; avoid `latest`; tag by commit SHA ([ADR-008](decisions/ADR-008-container-image-tagging.md))
- Place tasks only in private subnets; block direct internet ingress

## ECS on EC2 (capacity with ASG)

Adds/changes from Fargate:

- Auto Scaling Group + Launch Template with ECS-optimized AMI
- Instance profile granting ECS agent permissions (`AmazonEC2ContainerServiceforEC2Role` or equivalent minimal set)
- User data to join cluster (e.g., `ECS_CLUSTER=name`), or capacity providers mapped to the ASG

Gotchas:

- Patch AMIs regularly; handle drain on scale-in; ensure instance SG/route tables allow pulling images/logs

## Core VPC for ECS

Includes:

- VPC CIDR with room to grow, DNS hostnames on
- Public subnets (ALB/Bastion), private subnets (services/data) across 2–3 AZs
- NAT per AZ (prod) or single NAT (dev) and route tables
- VPC Endpoints: S3 (Gateway), ECR/ECR DKR (Interface), CloudWatch Logs, SSM, EC2 Messages, SSM Messages

Decisions:

- Prod HA? Use per‑AZ NAT and subnets; Dev? single‑AZ for cost
- Endpoint coverage based on build/runtime paths (pull images, logs, SSM)

Gotchas:

- Security groups referencing beats CIDR for intra‑VPC access; don’t forget DNS hostnames for ECS service discovery

Endpoints list example:

```terraform
locals {
  interface_endpoints = [
    "com.amazonaws.${var.region}.ecr.api",
    "com.amazonaws.${var.region}.ecr.dkr",
    "com.amazonaws.${var.region}.logs",
    "com.amazonaws.${var.region}.ssm",
    "com.amazonaws.${var.region}.ec2messages",
    "com.amazonaws.${var.region}.ssmmessages",
  ]
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id
}

resource "aws_vpc_endpoint" "interfaces" {
  for_each          = toset(local.interface_endpoints)
  vpc_id            = aws_vpc.main.id
  service_name      = each.value
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.endpoints.id]
}
```

## CloudFront + S3 OAC (private bucket)

Includes:

- CloudFront distribution, Origin Access Control (OAC), restrictive S3 bucket policy allowing CloudFront only
- Optional custom domain (ACM cert in us-east-1) and Route53 alias

Decisions:

- Cache behavior (TTL, querystrings, cookies), invalidation strategy, cross-region bucket vs distribution

Gotchas:

- Use OAC over legacy OAI; update bucket policy with `AWS:SourceArn = distribution_arn`
- ACM must be in us-east-1 for CloudFront

Route53 Alias to CloudFront:

```terraform
variable "cdn_hostname"   { type = string }  # e.g., cdn.example.com
variable "hosted_zone_id" { type = string }

resource "aws_route53_record" "cdn_alias" {
  zone_id = var.hosted_zone_id
  name    = var.cdn_hostname
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.cdn_oac.domain_name
    zone_id                = aws_cloudfront_distribution.cdn_oac.hosted_zone_id
    evaluate_target_health = false
  }
}
```

## RDS Pattern (private Postgres)

Includes:

- DB subnet group (private subnets across AZs), parameter group
- DB instance (Multi-AZ for prod, storage encrypted, backups, deletion protection)
- SG allowing only from app tier SG
- Secrets in SSM/Secrets Manager

Decisions:

- IO/storage sizing, maintenance window, performance insights, read replicas

Optional: AWS Backup (managed backups)

```terraform
resource "aws_backup_vault" "main" {
  name = "app-backup-vault"
}

resource "aws_backup_plan" "daily" {
  name = "daily-backups"
  rule {
    rule_name         = "daily-35d"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 5 * * ? *)" # 05:00 UTC daily
    lifecycle {
      delete_after = 35
    }
  }
}

resource "aws_backup_selection" "rds" {
  name         = "select-rds"
  plan_id      = aws_backup_plan.daily.id
  resources    = [aws_db_instance.postgres.arn]
  iam_role_arn = aws_iam_role.backup.arn
}
```

Gotchas:

- Ensure the backup service role exists; coordinate RPO/RTO with maintenance windows; validate restore tests

## Bastion Host (prefer bastionless with SSM)

Preferred (bastionless):

- No inbound SSH; use SSM Session Manager with instance profile granting SSM permissions
- Port-forward to RDS via SSM or use a temporary EC2/ECS task in a management subnet

Example (SSM-managed bastion without SSH open):

```terraform
resource "aws_iam_role" "bastion_ssm" {
  name = "bastion-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_ssm_core" {
  role       = aws_iam_role.bastion_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" { role = aws_iam_role.bastion_ssm.name }

resource "aws_instance" "bastion" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name
  metadata_options { http_tokens = "required" }
}

resource "aws_security_group" "bastion" {
  vpc_id = aws_vpc.main.id
  # No inbound rules required for SSM-only
  egress { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
}
```

If SSH required (legacy):

- Open 22 only to office IPs; require MFA/short-lived keys; disable public AMIs in prod

## ECR and Public Mirrors

Private ECR (immutable, lifecycle, scanning): see cheatsheet.

Pull Through Cache (mirror Docker Hub/quay):

```terraform
resource "aws_ecr_pull_through_cache_rule" "dockerhub" {
  ecr_repository_prefix = "dockerhub"
  upstream_registry_url = "registry-1.docker.io"
}
```

Public ECR Repository (publish images):

```terraform
resource "aws_ecrpublic_repository" "app" {
  repository_name = "my-public-app"
  catalog_data { about_text = "Public image for my app" }
}
```

Gotchas:

- Pull-through cache creates repos on first pull; use the prefixed path (`<account>.dkr.ecr.<region>.amazonaws.com/dockerhub/library/nginx:latest`)
- ECR Public uses a global public registry; IAM and rate limits differ from private ECR

## Monitoring/Dashboards/Alarms/Alerts

Includes:

- CloudWatch log groups (retention), metric filters for errors, dashboards for key metrics
- Alarms on app metrics and infrastructure; SNS topic for notifications and subscriptions

Decisions:

- Alert channels (email, Slack via Chatbot), severity and thresholds, composite alarms to reduce noise

Gotchas:

- Set `treat_missing_data` thoughtfully; add OK actions; ensure IAM allows services to publish to SNS

## Decision Checklists

Fargate vs EC2:

- Fargate: no servers, quicker ops, higher per-CPU cost; EC2: more control, potentially cheaper at scale, but capacity ops
- Need privileged/daemonset-like workloads? That leans to EC2

Public vs Private:

- ALB public, services private; use NAT + endpoints; no public IPs on workloads

Secrets & Encryption:

- Use SSM/Secrets Manager; KMS CMKs for S3/SNS/SQS; enable rotation where possible

Networking:

- Per-AZ NAT for prod; VPC Flow Logs; SG references over CIDRs for intra-VPC
