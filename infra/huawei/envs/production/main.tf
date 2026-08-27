module "network" {
  source = "../../modules/network"

  environment       = "production"
  region            = var.region
  availability_zone = var.availability_zone

  vpc_cidr        = var.vpc_cidr
  cce_subnet_cidr = var.cce_subnet_cidr
  rds_subnet_cidr = var.rds_subnet_cidr

  enterprise_project_id = var.enterprise_project_id
}

module "cce" {
  source = "../../modules/cce"

  environment       = "production"
  region            = var.region
  availability_zone = var.availability_zone

  vpc_id            = module.network.vpc_id
  subnet_id         = module.network.cce_subnet_id
  security_group_id = module.network.cce_security_group_id

  cluster_version         = var.cluster_version
  enable_ha_control_plane = var.enable_ha_control_plane

  node_flavor_id = var.node_flavor_id
  node_key_pair  = var.node_key_pair
  node_count     = var.node_count

  enterprise_project_id = var.enterprise_project_id
}

module "rds" {
  source = "../../modules/rds"

  environment               = "production"
  region                    = var.region
  availability_zone         = var.availability_zone
  availability_zone_standby = var.rds_availability_zone_standby

  vpc_id            = module.network.vpc_id
  subnet_id         = module.network.rds_subnet_id
  security_group_id = module.network.rds_security_group_id

  flavor            = var.rds_flavor
  db_engine_version = var.rds_engine_version

  enable_ha           = var.rds_enable_ha
  ha_replication_mode = var.rds_ha_replication_mode

  volume_type      = var.rds_volume_type
  volume_size      = var.rds_volume_size
  backup_keep_days = var.rds_backup_keep_days

  rds_password = var.rds_password

  enterprise_project_id = var.enterprise_project_id
}
