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
# VPC — public + private subnets across multiple AZs, single shared NAT
# gateway (cost-conscious: one NAT rather than one per AZ). EKS nodes and
# RDS both live in the private subnets; nothing is placed in the public
# subnets by this module.
# ---------------------------------------------------------------------------

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = [for i, az in var.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, az in var.azs : cidrsubnet(var.vpc_cidr, 4, i + 8)]

  enable_nat_gateway = true
  single_nat_gateway = true # cost-conscious: one NAT gateway shared by all private subnets

  enable_dns_hostnames = true

  # Lets EKS/AWS Load Balancer Controller auto-discover subnets for
  # ingress load balancers in a later phase (not created by this module).
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = {
    Environment = var.environment
    Project     = "cashonrails-assessment"
    Purpose     = "aws-validation"
  }
}
