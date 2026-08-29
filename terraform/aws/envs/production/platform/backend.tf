# Separate state from the main production environment (network/EKS/ECR/RDS/SSM-target) - see
# ../../staging/platform/backend.tf for the rationale (identical, mirrored per environment).
#
#   terraform init -backend-config=backend.hcl
#
# See ../backend.hcl.example for the exact bucket value (the bootstrap's state_bucket_name output).

terraform {
  backend "s3" {
    key          = "aws/production/platform/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
