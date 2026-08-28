terraform {
  required_version = ">= 1.15.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Deliberately no backend block. This root creates the remote state
  # backend for infra/aws/envs/* — it cannot depend on the backend it is
  # creating, so it always uses local state. It is run once, by hand, by
  # whoever bootstraps the account (see the repository's operational
  # notes for the exact command). It is not run by CI.
}

provider "aws" {
  region = var.aws_region
}
