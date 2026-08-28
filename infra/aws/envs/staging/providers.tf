terraform {
  required_version = ">= 1.15.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote S3 backend is configured in backend.tf (partial config — the
  # bucket name is supplied at `terraform init` time, not committed here).
}

provider "aws" {
  region = var.aws_region
}
