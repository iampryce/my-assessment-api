# Separate state from the main staging environment (network/EKS/ECR/RDS/SSM-target) - deliberately
# isolated so platform-layer applies (Argo CD/ingress-nginx/cert-manager, run by the
# platform-bootstrap identity) can never touch or be blocked by infra-layer state, and vice versa.
#
#   terraform init -backend-config=backend.hcl
#
# See ../backend.hcl.example for the exact bucket value (the bootstrap's state_bucket_name output).

terraform {
  backend "s3" {
    key          = "aws/staging/platform/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
