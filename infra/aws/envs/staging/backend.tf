# Partial backend configuration. Terraform backend blocks cannot reference
# variables, and the bucket name depends on the AWS account ID (from the
# bootstrap in infra/aws/bootstrap), which does not belong in committed
# code. Supply the bucket at `terraform init` time:
#
#   terraform init -backend-config=backend.hcl
#
# See backend.hcl.example for the exact value (the bootstrap's
# `state_bucket_name` output).

terraform {
  backend "s3" {
    key          = "aws/staging/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # native S3 state locking (Terraform >= 1.10) — no DynamoDB table
  }
}
