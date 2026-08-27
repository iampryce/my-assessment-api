terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

locals {
  name = "cashonrails-aws-${var.environment}"
}

# ---------------------------------------------------------------------------
# RDS security group — ingress restricted to the EKS node security group on
# 5432 only. No egress block is defined here, so this security group has no
# egress rules at all (Terraform manages inline ingress/egress blocks
# authoritatively — omitting egress means none exist, not "allow all").
# This mirrors the same restrictive, documented posture used for RDS on the
# Huawei side: there is no requirement for this database to originate its
# own outbound connections, security groups are stateful so replies to
# node-initiated connections still work, and AWS RDS's own management-plane
# traffic does not route through the customer-visible security group at
# all — it uses a separate control channel.
# ---------------------------------------------------------------------------

resource "aws_security_group" "rds" {
  name        = "${local.name}-rds-sg"
  description = "Allow PostgreSQL access from EKS worker nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.node_security_group_id]
  }

  tags = {
    Environment = var.environment
    Project     = "cashonrails-assessment"
    Purpose     = "aws-validation"
  }
}

# ---------------------------------------------------------------------------
# RDS for PostgreSQL — private only (publicly_accessible = false, no
# public IP), placed in the same private subnets as the EKS nodes (a
# deliberate simplification versus the Huawei side's dedicated RDS subnet —
# acceptable for a validation environment, not a production design
# decision).
#
# Credentials: manage_master_user_password defaults to true in this
# module, meaning AWS Secrets Manager generates and owns the master
# password — Terraform never sees, stores, or requires a plaintext
# credential anywhere in this configuration. No password variable exists
# in this file or any .tfvars file.
# ---------------------------------------------------------------------------

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 7.0"

  identifier = "${local.name}-rds"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage

  db_name  = "cashonrails"
  username = "cashonrails_admin"

  create_db_subnet_group = true
  subnet_ids             = var.subnet_ids

  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false
  multi_az            = var.multi_az

  backup_retention_period = var.backup_retention_period

  tags = {
    Environment = var.environment
    Project     = "cashonrails-assessment"
    Purpose     = "aws-validation"
  }
}
