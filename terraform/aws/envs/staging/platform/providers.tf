# Prerequisite for `terraform plan`/`apply` in this directory: the EKS API endpoint is
# private-only (see ../main.tf), so an SSM port-forwarding tunnel to 127.0.0.1:6443 must already be
# open, using the platform-bootstrap role - same mechanism application-ci.yml uses for kubectl,
# see the deployment runbook. `terraform validate`/`fmt`/`init` do not need the tunnel; `plan`/
# `apply` do, because the kubernetes/helm providers dial the cluster to read current state.
#
# tls_server_name overrides SNI to the real endpoint hostname so certificate validation stays
# intact against the tunnel's loopback address - never --insecure-skip-tls-verify equivalent.

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
