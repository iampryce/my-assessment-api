# Deliberately its own state, separate from the main staging root. Personal/admin
# EKS access entries must never be reconciled by the CI-driven eks-core.yml apply
# (which targets module.eks in ../main.tf) - a value only known to a local,
# gitignored terraform.tfvars gets silently deleted the moment CI applies with
# that value at its empty default. Isolating the state removes the shared
# resource entirely, so CI has nothing here to reconcile against.
#
# Supply the bucket at `terraform init` time, same as the main staging root:
#
#   terraform init -backend-config=backend.hcl

terraform {
  backend "s3" {
    key          = "aws/staging/admin-access/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # native S3 state locking (Terraform >= 1.10) — no DynamoDB table
  }
}
