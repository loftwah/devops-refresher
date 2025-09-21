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

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/eks-cluster/terraform.tfstate"
    region       = "us-east-1"
    profile      = "devops-sandbox"
    use_lockfile = true
    encrypt      = true
  }
}

locals {
  vpc_id_effective             = length(var.vpc_id) > 0 ? var.vpc_id : data.terraform_remote_state.vpc.outputs.vpc_id
  private_subnet_ids_effective = length(var.private_subnet_ids) > 0 ? var.private_subnet_ids : data.terraform_remote_state.vpc.outputs.private_subnet_ids
  app_sg_id_effective          = length(var.app_sg_id) > 0 ? var.app_sg_id : data.terraform_remote_state.sg.outputs.app_sg_id
  db_password_effective        = length(var.db_password) > 0 ? var.db_password : random_password.db.result
}

data "aws_vpc" "this" {
  id = local.vpc_id_effective
}

resource "random_password" "db" {
  length  = 24
  special = true
  # Avoid characters that can be problematic in RDS: / " @
  override_special = "!#$%^&*()-_=+[]{}<>?."
}

resource "aws_db_subnet_group" "this" {
  name       = "staging-rds-app"
  subnet_ids = local.private_subnet_ids_effective
}

resource "aws_security_group" "rds" {
  name        = "staging-rds-app"
  description = "RDS access for app"
  vpc_id      = local.vpc_id_effective
}

resource "aws_security_group_rule" "from_app_sg" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = local.app_sg_id_effective
}

# Also allow from the EKS cluster security group so pods (via node ENIs) can reach Postgres
data "aws_eks_cluster" "this" {
  name = try(data.terraform_remote_state.eks.outputs.cluster_name, "devops-refresher-staging")
}

resource "aws_security_group_rule" "from_cluster_sg" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

# Optional guardrail: allow from VPC CIDR during troubleshooting
resource "aws_security_group_rule" "from_vpc_cidr" {
  count             = 1
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  security_group_id = aws_security_group.rds.id
  cidr_blocks       = [data.aws_vpc.this.cidr_block]
  description       = "Temporary: allow Postgres from VPC CIDR for troubleshooting"
}

resource "aws_db_instance" "postgres" {
  identifier             = "staging-app-postgres"
  engine                 = "postgres"
  engine_version         = "14"
  instance_class         = var.instance_class
  allocated_storage      = 20
  db_name                = var.db_name
  username               = var.db_user
  password               = local.db_password_effective
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  deletion_protection    = false
}

# Store the DB password in Secrets Manager for app/runtime usage
resource "aws_secretsmanager_secret" "db_password" {
  name = "/devops-refresher/${var.env}/${var.service}/DB_PASS"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = local.db_password_effective
}
