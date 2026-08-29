# See ../../staging/platform/providers.tf for the full rationale - identical mechanism, pointed at
# the production cluster. The SSM tunnel must be open on 127.0.0.1:6443 before `plan`/`apply`.

terraform {
  required_version = ">= 1.15.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_eks_cluster" "this" {
  name = var.eks_cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.eks_cluster_name
}

locals {
  eks_endpoint_hostname = replace(data.aws_eks_cluster.this.endpoint, "https://", "")
}

provider "kubernetes" {
  host                   = "https://127.0.0.1:6443"
  tls_server_name        = local.eks_endpoint_hostname
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes = {
    host                   = "https://127.0.0.1:6443"
    tls_server_name        = local.eks_endpoint_hostname
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
