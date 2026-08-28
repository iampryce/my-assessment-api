module "network" {
  source = "../../modules/network"

  environment = "staging"
  vpc_cidr    = var.vpc_cidr
  azs         = var.azs
}

module "ecr" {
  source = "../../modules/ecr"

  environment = "staging"
}

module "eks" {
  source = "../../modules/eks"

  environment = "staging"

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids

  kubernetes_version = var.kubernetes_version

  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
}

module "rds" {
  source = "../../modules/rds"

  environment = "staging"

  vpc_id                 = module.network.vpc_id
  subnet_ids             = module.network.private_subnet_ids
  node_security_group_id = module.eks.node_security_group_id

  engine_version    = var.rds_engine_version
  instance_class    = var.rds_instance_class
  allocated_storage = var.rds_allocated_storage

  multi_az                = var.rds_multi_az
  backup_retention_period = var.rds_backup_retention_period
}
