# Terraform Resource Cheatsheet

This is a cheatsheet for the Terraform resources I use most often.

## AWS Provider

[AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

Example:

- Basic Provider Configuration

```terraform
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

variable "aws_region" { type = string }
variable "aws_profile" { type = string }
```

Tip: Prefer specifying provider version constraints and pin your region/profile via variables for reuse across workspaces.

Best practices:

- Use `default_tags` in the provider to apply consistent tags across resources.
- Keep credentials out of code; use profiles/SSO/assume-role. Store state remotely (S3 backend) with locking: backend lockfile (Terraform v1.13+) or DynamoDB table for <=1.9.

### AWS KMS Key

[aws_kms_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key)

Example:

- CMK with rotation and alias

```terraform
resource "aws_kms_key" "app" {
  description         = "CMK for app data"
  enable_key_rotation = true
}

resource "aws_kms_alias" "app" {
  name          = "alias/app"
  target_key_id = aws_kms_key.app.key_id
}
```

Best practices:

- Enable rotation; prefer customer-managed keys for auditability; scope key policies minimally.
- Use aliases (e.g., `alias/app`) and reference keys by alias in dependent resources when possible.

### AWS Route53 Record

[aws_route53_record](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record)

Example:

- A Alias to ALB

```terraform
variable "hosted_zone_id" { type = string }
variable "record_name"    { type = string } # e.g., app.example.com

resource "aws_route53_record" "alb_alias" {
  zone_id = var.hosted_zone_id
  name    = var.record_name
  type    = "A"
  alias {
    name                   = aws_lb.web.dns_name
    zone_id                = aws_lb.web.zone_id
    evaluate_target_health = true
  }
}
```

- CNAME record

```terraform
resource "aws_route53_record" "cname" {
  zone_id = var.hosted_zone_id
  name    = "api.example.com"
  type    = "CNAME"
  ttl     = 60
  records = ["target.example.net"]
}
```

Notes:

- Use A/AAAA ALIAS for AWS targets (ALB/CloudFront/S3 website) instead of CNAME at zone apex.

### AWS S3 Bucket

[AWS S3 Bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket)

Example:

- Private Bucket With Tags

```terraform
resource "aws_s3_bucket" "unique-name-example" {
  bucket = "my-tf-test-bucket"

  tags = {
    Name        = "My Bucket"
    Environment = "Development"
    Owner       = "Dean Lofts"
    CostCenter  = "12345"
    Project     = "some-project"
    App         = "some-app"
  }
}
```

Best practices:

- Start with conservative `min_capacity` to control cost; set reasonable `max_capacity` to cap spend.
- Use target tracking on meaningful metrics (CPU, memory via CW agent, or ALB `RequestCountPerTarget`).

Best practices:

- For sensitive data, use KMS CMK (`kms_master_key_id`) instead of SSE‑S3; audit with CloudTrail data events.

Best practices:

- Enable at‑rest and in‑transit encryption with AUTH tokens; restrict access via tight SGs.
- Use Multi‑AZ with automatic failover; prefer replication groups (cluster mode where applicable) over single clusters.

Best practices:

- For production, enable Multi‑AZ, storage encryption, Performance Insights, automatic backups, and deletion protection.
- Source credentials from Secrets Manager/SSM (KMS encrypted); restrict SGs to app tier only.

Best practices:

- Calibrate thresholds with real traffic; use composite alarms to reduce noise and add OK actions for closure.

Best practices:

- Set retention per environment/compliance; avoid infinite retention unless required.
- Use structured logging (JSON) to enable metric filters and insights queries.

Best practices:

- Prefer `IMMUTABLE` tags to prevent overwrite; tag images with CI build IDs/commit SHAs.
- Apply restrictive repo policies; grant CI least privilege for push/pull.

Best practices:

- Prefer CodeStar Connections for Git sources; encrypt the artifact bucket with KMS and enable bucket PAB + versioning.
- Scope the pipeline role minimally; separate per‑environment pipelines to reduce blast radius.

Best practices:

- Don’t hardcode secrets; pull from SSM/Secrets Manager env vars. Use KMS‑encrypted env variables for sensitive values.
- For private builds, configure VPC subnets and endpoints (ECR, S3, CloudWatch Logs) to avoid public internet egress.

Best practices:

- Use Origin Access Control (OAC) to access S3 and restrict the bucket policy; avoid public S3.
- For custom domains, create the ACM cert in us‑east‑1, add `aliases`, and enable minimal TTLs for dynamic content.

Best practices:

- Use distinct execution and task roles (least privilege); keep images pinned to immutable tags instead of `latest`.
- Source secrets from AWS Secrets Manager/SSM via container `secrets`; avoid plaintext `environment` values for secrets.

Best practices:

- Principle of least privilege: open only required ports/sources; avoid `0.0.0.0/0` except for public web ports.
- Use separate SGs per tier and reference SG IDs instead of wide CIDRs for internal traffic.

Best practices:

- Plan CIDRs to avoid overlap with peers/VPNs; leave room for future AZs.
- Enable VPC Flow Logs to CloudWatch or S3 for network auditing.

Notes:

- Avoid ACLs: Prefer IAM/bucket policies and set `aws_s3_bucket_ownership_controls` to `BucketOwnerEnforced` to disable ACLs entirely.
- Block public access: Keep `aws_s3_bucket_public_access_block` fully enabled unless you have a vetted exception.
- Access via CloudFront: For public content, use CloudFront with Origin Access Control (OAC) and a bucket policy allowing only your distribution.
- Encryption + versioning: Enable default SSE (`AES256` or KMS) and versioning for safety and rollback.

### AWS S3 Bucket ACL

[aws_s3_bucket_acl](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_acl)

Example:

- Private ACL

```terraform
resource "aws_s3_bucket" "logs" {
  bucket = "my-logs-bucket-example"
}

resource "aws_s3_bucket_acl" "logs" {
  bucket = aws_s3_bucket.logs.id
  acl    = "private"
}
```

Warning: Avoid ACLs by default. Prefer `BucketOwnerEnforced` object ownership (disables ACLs) with IAM/bucket policies. Only use ACLs for legacy or specific integrations that explicitly require them; if you must, keep Public Access Block enabled and scope ACLs narrowly.

### AWS S3 Bucket Ownership Controls

[aws_s3_bucket_ownership_controls](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls)

Example:

- Enforce BucketOwnerEnforced (no ACLs)

```terraform
resource "aws_s3_bucket" "data" {
  bucket = "my-data-bucket-example"
}

resource "aws_s3_bucket_ownership_controls" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
```

Tip: BucketOwnerEnforced disables ACLs; combine with IAM policies and PAB for least privilege.

### AWS S3 Bucket Public Access Block

[aws_s3_bucket_public_access_block](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block)

Example:

- Block Public Access

```terraform
resource "aws_s3_bucket" "artifacts" {
  bucket = "my-artifacts-bucket-example"
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

### AWS S3 Bucket Server Side Encryption

[aws_s3_bucket_server_side_encryption_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration)

Example:

- Default SSE-S3

```terraform
resource "aws_s3_bucket" "backups" {
  bucket = "my-backups-bucket-example"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

Alternate: Default SSE with KMS CMK

```terraform
resource "aws_kms_key" "s3" {
  description         = "KMS key for S3 default encryption"
  enable_key_rotation = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups_kms" {
  bucket = aws_s3_bucket.backups.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
  }
}
```

### AWS S3 Bucket Versioning

[aws_s3_bucket_versioning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning)

Example:

- Enable Versioning

```terraform
resource "aws_s3_bucket" "state" {
  bucket = "my-tf-state-bucket-example"
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

### AWS VPC

[aws_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc)

Example:

- Basic VPC

```terraform
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}
```

### AWS Subnet

[aws_subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet)

Example:

- Public and Private Subnets

```terraform
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = { Name = "public-a" }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${var.aws_region}a"
  tags = { Name = "private-a" }
}
```

Best practices:

- Create subnets in at least two AZs per tier for HA (e.g., `public_a/public_b`, `private_a/private_b`).
- Keep public subnets minimal; place workloads in private subnets and access via ALB/NLB or SSM.

### AWS Internet Gateway

[aws_internet_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway)

Example:

- IGW for Public Subnets

```terraform
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "main-igw" }
}
```

### AWS Nat Gateway

[aws_nat_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway)

Example:

- NAT in Public Subnet

```terraform
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  tags = { Name = "main-nat" }
}
```

Best practices:

- For production, deploy one NAT per AZ and route each private subnet to the local NAT; for dev/sandbox, a single NAT saves cost.

### AWS EIP

[aws_eip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip)

Example:

- EIP for Instance

```terraform
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public_a.id
}

resource "aws_eip" "web" {
  domain   = "vpc"
  instance = aws_instance.web.id
}
```

Best practices:

- Prefer SSM Session Manager over SSH; remove port 22 and attach `AmazonSSMManagedInstanceCore` via instance profile.
- Enforce IMDSv2 (`metadata_options { http_tokens = "required" }`), encrypt EBS, and avoid public IPs on servers in private subnets.

### AWS Route Table

[aws_route_table](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table)

Example:

- Public and Private Route Tables

```terraform
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "private-rt" }
}
```

### AWS Route Table Association

[aws_route_table_association](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association)

Example:

- Associate Subnets

```terraform
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}
```

### AWS Security Group

[aws_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)

Example:

- Web SG Allow 80/443

```terraform
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Allow web inbound"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### AWS Security Group Rule

[aws_security_group_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule)

Example:

- Separate SSH Rule

```terraform
resource "aws_security_group_rule" "ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["203.0.113.0/24"]
  security_group_id = aws_security_group.web.id
  description       = "SSH from office"
}
```

### AWS EC2 Instance

[aws_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance)

Example:

- Simple Web Server

```terraform
resource "aws_instance" "web" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.web.id]
  user_data              = file("user_data/web.sh")

  tags = { Name = "web-1" }
}
```

### AWS IAM Role

[aws_iam_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)

Example:

- EC2 Assume Role

```terraform
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}
```

Best practices:

- Keep trust relationships minimal and specific; tag roles and prefer customer‑managed policies over inline.

### AWS IAM Policy

[aws_iam_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy)

Example:

- S3 Read-Only Policy

```terraform
data "aws_iam_policy_document" "s3_ro" {
  statement {
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"]
  }
}

resource "aws_iam_policy" "s3_ro" {
  name   = "S3ReadOnly"
  policy = data.aws_iam_policy_document.s3_ro.json
}
```

### AWS IAM Role Policy

[aws_iam_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy)

Example:

- Inline Policy on Role

```terraform
resource "aws_iam_role_policy" "ec2_inline" {
  name = "allow-ssm"
  role = aws_iam_role.ec2.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:SendCommand", "ssmmessages:CreateControlChannel", "ec2messages:GetMessagesForInstance"]
      Resource = "*"
    }]
  })
}
```

Best practices:

- Use reusable managed policies where possible; reserve inline policies for narrowly scoped, role‑specific permissions.

### AWS IAM Role Policy Attachment

[aws_iam_role_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment)

Example:

- Attach Managed Policy

```terraform
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

Best practices:

- Attach only required managed policies; avoid overly broad AWS managed policies in production.

### AWS IAM Instance Profile

[aws_iam_instance_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile)

Example:

- Instance Profile for EC2

```terraform
resource "aws_iam_instance_profile" "ec2" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2.name
}
```

### AWS CloudWatch Log Group

[aws_cloudwatch_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group)

Example:

- App Log Group with Retention

```terraform
resource "aws_cloudwatch_log_group" "app" {
  name              = "/app/web"
  retention_in_days = 30
  tags = { Environment = "dev" }
}
```

### AWS CloudWatch Log Metric Filter

[aws_cloudwatch_log_metric_filter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_metric_filter)

Example:

- Error Count Metric

```terraform
resource "aws_cloudwatch_log_metric_filter" "errors" {
  name           = "app-error-count"
  log_group_name = aws_cloudwatch_log_group.app.name
  pattern        = "ERROR"
  metric_transformation {
    name      = "AppErrorCount"
    namespace = "App/Metrics"
    value     = "1"
  }
}
```

### AWS CloudWatch Metric Alarm

[aws_cloudwatch_metric_alarm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm)

Example:

- Alarm on Error Count

```terraform
resource "aws_cloudwatch_metric_alarm" "errors_high" {
  alarm_name          = "app-errors-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "AppErrorCount"
  namespace           = "App/Metrics"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "High error rate"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
```

### AWS CloudWatch Dashboard

[aws_cloudwatch_dashboard](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_dashboard)

Example:

- Simple Dashboard

```terraform
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "app-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        x    = 0
        y    = 0
        width = 12
        height = 6
        properties = {
          metrics = [["App/Metrics", "AppErrorCount"]]
          period  = 60
          stat    = "Sum"
          title   = "Error Count"
        }
      }
    ]
  })
}
```

### AWS SNS Topic

[aws_sns_topic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic)

Example:

- Alerts Topic

```terraform
resource "aws_sns_topic" "alerts" {
  name = "app-alerts"
}
```

Best practices:

- Enable KMS encryption for topics handling sensitive messages.
- Constrain publish/subscribe via topic policies; avoid wildcard principals.

### AWS SNS Topic Policy

[aws_sns_topic_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy)

Example:

- Allow CloudWatch to Publish

```terraform
data "aws_iam_policy_document" "sns_cw" {
  statement {
    effect = "Allow"
    principals { type = "Service", identifiers = ["cloudwatch.amazonaws.com"] }
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
  }
}

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.sns_cw.json
}
```

### AWS SNS Topic Subscription

[aws_sns_topic_subscription](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription)

Example:

- Email Subscription

```terraform
resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "alerts@example.com"
}
```

### AWS SQS Queue

[aws_sqs_queue](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue)

Example:

- Standard Queue with DLQ

```terraform
resource "aws_sqs_queue" "dlq" {
  name = "app-dlq"
}

resource "aws_sqs_queue" "queue" {
  name                      = "app-queue"
  visibility_timeout_seconds = 30
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn,
    maxReceiveCount     = 5
  })
}
```

Best practices:

- Enable KMS encryption for sensitive messages; configure long polling (`receive_wait_time_seconds`) to reduce empty receives.
- Set `visibility_timeout_seconds` > max processing time; use DLQs with appropriate `maxReceiveCount`.

### AWS SSM Parameter

[aws_ssm_parameter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter)

Example:

- Secure String

```terraform
resource "aws_ssm_parameter" "db_password" {
  name  = "/app/db/password"
  type  = "SecureString"
  value = var.db_password
}
```

Best practices:

- Use a customer managed KMS key via `key_id` for sensitive values; scope IAM to least privilege paths (e.g., `/app/*`).

### AWS VPC Endpoint

[aws_vpc_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint)

Example:

- Gateway Endpoint for S3

```terraform
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  tags = { Name = "s3-endpoint" }
}
```

Best practices:

- Add an endpoint policy to restrict access to specific buckets/services. For private VPCs, add endpoints for SSM, EC2 Messages, Logs, and ECR to avoid NAT egress.

### AWS ECR Repository

[aws_ecr_repository](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository)

Example:

- Private Repo with Scan On Push

```terraform
resource "aws_ecr_repository" "app" {
  name                 = "app-repo"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  tags = { Project = "some-app" }
}
```

### AWS ECR Lifecycle Policy

[aws_ecr_lifecycle_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_lifecycle_policy)

Example:

- Keep Last 10 Images

```terraform
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1,
      description  = "keep last 10",
      selection    = {
        tagStatus   = "any",
        countType   = "imageCountMoreThan",
        countNumber = 10
      },
      action = { type = "expire" }
    }]
  })
}
```

### AWS ECS Cluster

[aws_ecs_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster)

Example:

- ECS Cluster with Container Insights

```terraform
resource "aws_ecs_cluster" "this" {
  name = "app-cluster"
  setting { name = "containerInsights" value = "enabled" }
}
```

Best practices:

- Enable Container Insights for metrics/logs; consider CloudWatch Agent for extra telemetry.
- Prefer capacity providers with a default strategy to mix on‑demand and spot for cost control.

### AWS ECS Cluster Capacity Providers

[aws_ecs_cluster_capacity_providers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers)

Example:

- Use FARGATE and FARGATE_SPOT

```terraform
resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}
```

### AWS ECS Task Definition

[aws_ecs_task_definition](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition)

Example:

- Fargate Task Def

```terraform
resource "aws_ecs_task_definition" "web" {
  family                   = "web"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_exec.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  container_definitions = jsonencode([
    {
      name  = "web"
      image = "${aws_ecr_repository.app.repository_url}:latest"
      portMappings = [{ containerPort = 80, hostPort = 80 }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "web"
        }
      }
    }
  ])
}
```

### AWS ECS Service

[aws_ecs_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service)

Example:

- Fargate Service behind ALB

```terraform
resource "aws_ecs_service" "web" {
  name            = "web"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.private_a.id]
    security_groups = [aws_security_group.web.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.web.arn
    container_name   = "web"
    container_port   = 80
  }
  depends_on = [aws_lb_listener.http]
}
```

Best practices:

- Run tasks in private subnets; disable public IPs and restrict ingress to the ALB SG.
- Use deployment circuit breaker and health check grace period; autoscale using App Auto Scaling policies.

Add: Circuit Breaker + Exec

```terraform
resource "aws_ecs_service" "web" {
  # ...existing config...
  enable_execute_command             = true
  health_check_grace_period_seconds  = 60
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
}
```

### AWS LB

[aws_lb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb)

Example:

- Application Load Balancer

```terraform
resource "aws_lb" "web" {
  name               = "web-alb"
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_a.id]
  security_groups    = [aws_security_group.web.id]
}
```

Best practices:

- Use a dedicated SG for the ALB and a separate SG for service tasks; allow only from ALB SG to service SG.
- Prefer HTTPS with ACM; redirect HTTP→HTTPS at the listener.

### AWS LB Target Group

[aws_lb_target_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group)

Example:

- HTTP Target Group for ECS

```terraform
resource "aws_lb_target_group" "web" {
  name        = "web-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check { path = "/" }
}
```

### AWS LB Listener

[aws_lb_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener)

Example:

- HTTP Listener

```terraform
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
```

Alternate: HTTPS Listener + HTTP→HTTPS Redirect

```terraform
# Provide an ACM cert ARN (same region as the ALB)
variable "acm_certificate_arn" { type = string }

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.web.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.web.arn
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
```

Gotchas:

- ACM cert must be in the same region as the ALB (for CloudFront use us-east-1).
- For ECS Fargate, use target group `target_type = "ip"`; instance target type will fail health checks.
- Ensure SG rules: ALB SG allows 80/443 from internet; service SG allows from ALB SG only.

Best practices:

- Add a port 443 listener with an ACM certificate; redirect port 80 to 443.

### AWS Lambda Function

[aws_lambda_function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function)

Example:

- Inline Zip (Hello World)

```terraform
data "archive_file" "hello_zip" {
  type        = "zip"
  output_path = "build/hello.zip"
  source {
    content  = "exports.handler = async ()=>({statusCode:200, body:'ok'})"
    filename = "index.js"
  }
}

resource "aws_lambda_function" "hello" {
  function_name = "hello"
  role          = aws_iam_role.lambda.arn
  runtime       = "nodejs18.x"
  handler       = "index.handler"
  filename      = data.archive_file.hello_zip.output_path
}
```

Best practices:

- Prefer arm64 architecture where supported for cost/performance; pin exact runtime versions and minimize IAM permissions.
- Externalize secrets to SSM/Secrets Manager; set log retention on the log group to avoid infinite retention.

### AWS Lambda Permission

[aws_lambda_permission](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission)

Example:

- Allow API Gateway to Invoke

```terraform
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = aws_apigatewayv2_api.http_api.execution_arn
}
```

Best practices:

- Scope `source_arn` narrowly to the specific API/route/stage; avoid wildcard principals or account‑wide access.

### AWS CloudFront Distribution

[aws_cloudfront_distribution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution)

Example:

- S3 Static Website (OAC recommended in production)

```terraform
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name = aws_s3_bucket.artifacts.bucket_regional_domain_name
    origin_id   = "s3-artifacts"
  }

  default_cache_behavior {
    target_origin_id       = "s3-artifacts"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    forwarded_values { query_string = false cookies { forward = "none" } }
  }

  restrictions { geo_restriction { restriction_type = "none" } }
  viewer_certificate { cloudfront_default_certificate = true }
}
```

Add OAC + Restrictive S3 Bucket Policy

```terraform
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cdn_oac" {
  enabled = true
  origin {
    domain_name              = aws_s3_bucket.artifacts.bucket_regional_domain_name
    origin_id                = "s3-artifacts-oac"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }
  default_cache_behavior {
    target_origin_id       = "s3-artifacts-oac"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    forwarded_values { query_string = false cookies { forward = "none" } }
  }
  restrictions { geo_restriction { restriction_type = "none" } }
  viewer_certificate { cloudfront_default_certificate = true }
}

data "aws_iam_policy_document" "s3_cloudfront_oac" {
  statement {
    sid     = "AllowCloudFrontServicePrincipalReadOnly"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.artifacts.arn}/*"]
    principals { type = "Service" identifiers = ["cloudfront.amazonaws.com"] }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cdn_oac.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "artifacts_cf" {
  bucket = aws_s3_bucket.artifacts.id
  policy = data.aws_iam_policy_document.s3_cloudfront_oac.json
}
```

### AWS CodeBuild Project

[aws_codebuild_project](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project)

Example:

- Simple Build with Logs

```terraform
resource "aws_codebuild_project" "app" {
  name         = "app-build"
  service_role = aws_iam_role.codebuild.arn
  artifacts { type = "NO_ARTIFACTS" }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = false
    environment_variable { name = "ENV" value = "dev" }
  }
  source {
    type     = "GITHUB"
    location = "https://github.com/example/repo.git"
    buildspec = <<-YAML
      version: 0.2
      phases:
        build:
          commands:
            - echo Building
      YAML
  }
  logs_config {
    cloudwatch_logs { group_name = aws_cloudwatch_log_group.app.name }
  }
}
```

### AWS CodePipeline

[aws_codepipeline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codepipeline)

Example:

- S3 Source → CodeBuild

```terraform
resource "aws_s3_bucket" "pipeline_artifacts" { bucket = "pipeline-artifacts-example" }

resource "aws_codepipeline" "app" {
  name     = "app-pipeline"
  role_arn = aws_iam_role.codepipeline.arn
  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["source_out"]
      configuration = {
        S3Bucket = aws_s3_bucket.artifacts.bucket
        S3ObjectKey = "source.zip"
      }
    }
  }
  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_out"]
      output_artifacts = ["build_out"]
      configuration = {
        ProjectName = aws_codebuild_project.app.name
      }
    }
  }
}
```

### AWS CodeStar Connections Connection

[aws_codestarconnections_connection](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codestarconnections_connection)

Example:

- GitHub Connection (requires console handshake)

```terraform
resource "aws_codestarconnections_connection" "github" {
  name          = "github-conn"
  provider_type = "GitHub"
}
```

### AWS CodeStar Notifications Rule

[aws_codestarnotifications_notification_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codestarnotifications_notification_rule)

Example:

- Notify Pipeline State Changes to SNS

```terraform
resource "aws_codestarnotifications_notification_rule" "pipeline" {
  name        = "pipeline-notify"
  detail_type = "FULL"
  event_type_ids = [
    "codepipeline-pipeline-pipeline-execution-failed",
    "codepipeline-pipeline-pipeline-execution-succeeded"
  ]
  resource = aws_codepipeline.app.arn
  targets { address = aws_sns_topic.alerts.arn type = "SNS" }
}
```

### AWS App Auto Scaling Target

[aws_appautoscaling_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target)

Example:

- Scale ECS Service by DesiredCount

```terraform
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.web.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
```

### AWS App Auto Scaling Policy

[aws_appautoscaling_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy)

Example:

- Target Tracking on CPU 50%

```terraform
resource "aws_appautoscaling_policy" "ecs_cpu" {
  name               = "ecs-cpu-tt"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 50
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}
```

### AWS App Auto Scaling Scheduled Action

[aws_appautoscaling_scheduled_action](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_scheduled_action)

Example:

- Off-hours Scale Down

```terraform
resource "aws_appautoscaling_scheduled_action" "night" {
  name               = "ecs-scale-night"
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  schedule           = "cron(0 18 ? * MON-FRI *)" # 6pm UTC
  scalable_target_action { min_capacity = 1 max_capacity = 2 }
}
```

### AWS RDS DB Subnet Group

[aws_db_subnet_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group)

Example:

- Private Subnets for RDS

```terraform
resource "aws_db_subnet_group" "main" {
  name       = "main-db-subnets"
  subnet_ids = [aws_subnet.private_a.id]
  tags = { Name = "db-subnets" }
}
```

### AWS RDS Parameter Group

[aws_db_parameter_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group)

Example:

- Custom Parameter

```terraform
resource "aws_db_parameter_group" "pg" {
  name   = "app-pg"
  family = "postgres15"
  parameter { name = "log_min_duration_statement" value = "500" }
}
```

### AWS RDS Option Group

[aws_db_option_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_option_group)

Example:

- Option Group (engine-specific)

```terraform
resource "aws_db_option_group" "og" {
  name                 = "app-og"
  engine_name          = "oracle-ee"
  major_engine_version = "19"
}
```

### AWS RDS DB Instance

[aws_db_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance)

Example:

- Postgres in Private Subnets

```terraform
resource "aws_db_instance" "postgres" {
  identifier              = "app-postgres"
  engine                  = "postgres"
  engine_version          = "15"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = "app"
  username                = "app"
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.web.id]
  skip_final_snapshot     = true
  publicly_accessible     = false
  backup_retention_period = 7
  parameter_group_name    = aws_db_parameter_group.pg.name
}
```

### AWS ElastiCache Subnet Group

[aws_elasticache_subnet_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_subnet_group)

Example:

- Subnets for Redis

```terraform
resource "aws_elasticache_subnet_group" "main" {
  name       = "redis-subnets"
  subnet_ids = [aws_subnet.private_a.id]
}
```

### AWS ElastiCache Parameter Group

[aws_elasticache_parameter_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_parameter_group)

Example:

- Redis Params

```terraform
resource "aws_elasticache_parameter_group" "redis" {
  name   = "redis-pg"
  family = "redis7"
  parameter { name = "maxmemory-policy" value = "allkeys-lru" }
}
```

### AWS ElastiCache Cluster

[aws_elasticache_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_cluster)

Example:

- Redis Cluster (cluster mode disabled)

```terraform
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "app-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = aws_elasticache_parameter_group.redis.name
  subnet_group_name    = aws_elasticache_subnet_group.main.name
}
```

Alternate: Memcached Cluster

```terraform
resource "aws_elasticache_parameter_group" "memcached" {
  name   = "memcached-pg"
  family = "memcached1.6"
  parameter { name = "max_item_size" value = "2m" }
}

resource "aws_elasticache_cluster" "memcached" {
  cluster_id           = "app-memcached"
  engine               = "memcached"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 2
  parameter_group_name = aws_elasticache_parameter_group.memcached.name
  subnet_group_name    = aws_elasticache_subnet_group.main.name
}
```

Best practices:

- Memcached: stateless and in-memory only; size node count and client hashing for your traffic; no encryption/auth — place strictly in private subnets with tight SGs.

### AWS ElastiCache Replication Group

[aws_elasticache_replication_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group)

Example:

- Redis Replication Group

```terraform
resource "aws_elasticache_replication_group" "redis_rg" {
  replication_group_id          = "app-redis-rg"
  description                   = "Highly available Redis"
  engine                        = "redis"
  engine_version                = "7.0"
  node_type                     = "cache.t3.micro"
  number_cache_clusters         = 2
  automatic_failover_enabled    = true
  parameter_group_name          = aws_elasticache_parameter_group.redis.name
  subnet_group_name             = aws_elasticache_subnet_group.main.name
}
```

### AWS EIP (Standalone)

[aws_eip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip)

Example:

- EIP for NAT or EC2 (see earlier examples)

```terraform
# See separate aws_eip examples above.
```

### AWS Lambda + Permission Note

Tip: Always ensure the IAM role for Lambda has execution permissions (logs:CreateLogGroup/Stream, logs:PutLogEvents) and add explicit `aws_lambda_permission` when invoking from API Gateway, S3, or EventBridge.

### AWS CloudWatch Note

Tip: When creating metric alarms on custom metrics, ensure the producer emits the metric in the exact namespace/name and with the correct dimensions. Use `treat_missing_data` to avoid false alarms during deployment.
