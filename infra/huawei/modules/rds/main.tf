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

  availability_zones = (
    var.enable_ha && var.availability_zone_standby != null
    ? [var.availability_zone, var.availability_zone_standby]
    : [var.availability_zone]
  )
}

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
    port     = 5432
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
