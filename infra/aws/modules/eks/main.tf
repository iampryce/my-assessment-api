locals {
  name = "cashonrails-aws-${var.environment}"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.name
  kubernetes_version = var.kubernetes_version

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.subnet_ids

  endpoint_public_access  = false
  endpoint_private_access = true

  eks_managed_node_groups = {
    default = {
      name = local.name

      instance_types = [var.node_instance_type]

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      subnet_ids = var.subnet_ids
    }
  }

  tags = {
    Environment = var.environment
    Project     = "cashonrails-assessment"
    Purpose     = "aws-validation"
  }
}
