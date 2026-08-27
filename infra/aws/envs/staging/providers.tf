terraform {
  required_version = ">= 1.15.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # No remote backend configured yet — same deferred decision as the
  # Huawei environments (infra/huawei/envs/*). This is a temporary AWS
  # validation environment; local state is acceptable for now.
}

provider "aws" {
  region = var.aws_region
}
