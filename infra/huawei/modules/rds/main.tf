terraform {
  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "~> 1.70"
    }
  }
}

locals {
  name_prefix = "cashonrails-${var.environment}"

  # A second AZ is only meaningful (and only supplied) when HA is enabled
  # and a standby AZ has actually been given.
  availability_zones = (
    var.enable_ha && var.availability_zone_standby != null
    ? [var.availability_zone, var.availability_zone_standby]
    : [var.availability_zone]
  )
}

# ---------------------------------------------------------------------------
# RDS for PostgreSQL — private connectivity only.
#
# No public_ip/EIP argument exists on this resource at all (verified against
# the provider schema before implementing) — public access to RDS would be a
# separate, additional resource this module simply never creates. Combined
# with placement in the existing private rds subnet (no route to the
# internet — see the network module) and the existing rds security group
# (ingress from the cce security group on 5432 only, no public ingress),
# there is no path to a public IP anywhere in this module.
#
# Credentials: db.password is wired to var.rds_password, which has no
# default and is marked sensitive. Its real value is never written to any
# .tf or .tfvars file — it must be supplied at apply time via the
# TF_VAR_rds_password environment variable, sourced from Infisical.
# ---------------------------------------------------------------------------

resource "huaweicloud_rds_instance" "this" {
  name          = "${local.name_prefix}-rds"
  flavor        = var.flavor
  charging_mode = "postPaid"

  vpc_id            = var.vpc_id
  subnet_id         = var.subnet_id
  security_group_id = var.security_group_id
  availability_zone = local.availability_zones

  enterprise_project_id = var.enterprise_project_id

  db {
    type     = "PostgreSQL"
    version  = var.db_engine_version
    password = var.rds_password
    port     = 5432 # must match the network module's rds security group rule
  }

  volume {
    type = var.volume_type
    size = var.volume_size
  }

  backup_strategy {
    keep_days  = var.backup_keep_days
    start_time = var.backup_start_time
  }

  ha_replication_mode = var.enable_ha ? var.ha_replication_mode : null
}
