data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket  = var.vpc_state_bucket
    key     = var.vpc_state_key
    region  = var.vpc_state_region
    profile = var.aws_profile
  }
}

data "aws_vpc" "this" {
  id = data.terraform_remote_state.vpc.outputs.vpc_id
}

# Discover the private route table by Name tag set in Lab 01
data "aws_route_tables" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
  filter {
    name   = "tag:Name"
    values = [var.private_route_table_name]
  }
}

resource "aws_security_group" "endpoints" {
  name   = "staging-vpce"
  vpc_id = data.aws_vpc.this.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.this.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "staging-vpce" })
}

resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_gateway ? 1 : 0

  vpc_id            = data.aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_route_tables.private.ids

  tags = merge(var.tags, { Name = "staging-s3-endpoint" })
}

locals {
  interface_endpoints = toset(distinct(concat(
    var.interface_endpoints,
    var.enable_secretsmanager ? ["secretsmanager"] : [],
    var.enable_kms ? ["kms"] : [],
    var.enable_sts ? ["sts"] : [],
    var.enable_monitoring ? ["monitoring"] : [],
    var.enable_efs ? ["elasticfilesystem"] : [],
    var.enable_events ? ["events"] : []
  )))
}

resource "aws_vpc_endpoint" "interfaces" {
  for_each = local.interface_endpoints

  vpc_id              = data.aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.terraform_remote_state.vpc.outputs.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, { Name = "staging-${replace(each.value, ".", "-")}-vpce" })
}

# Optional: DynamoDB Gateway endpoint
resource "aws_vpc_endpoint" "dynamodb" {
  count = var.enable_dynamodb_gateway ? 1 : 0

  vpc_id            = data.aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_route_tables.private.ids

  tags = merge(var.tags, { Name = "staging-dynamodb-endpoint" })
}
