terraform {
  required_version = ">= 1.15.0, < 2.0.0"

  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "~> 1.70"
    }
  }

  # Remote state backend intentionally NOT configured yet.
  # This root module currently uses local state. A remote, OBS-backed
  # backend (Terraform's "s3" backend pointed at OBS's S3-compatible
  # endpoint) will be added in a later slice once the state-bucket
  # bootstrap process is decided — see the approved Phase 2a plan.
}

provider "huaweicloud" {
  region = var.region

  # Credentials are intentionally NOT set here.
  # Provide via environment variables: HW_ACCESS_KEY / HW_SECRET_KEY.
}
