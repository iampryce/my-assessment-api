module "network" {
  source = "../../modules/network"

  environment       = "staging"
  region            = var.region
  availability_zone = var.availability_zone

  vpc_cidr        = var.vpc_cidr
  cce_subnet_cidr = var.cce_subnet_cidr
  rds_subnet_cidr = var.rds_subnet_cidr

  enterprise_project_id = var.enterprise_project_id
}
