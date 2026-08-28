variable "aws_region" {
  description = "AWS region for the state bucket and IAM resources (IAM is global, but the provider still needs a region)."
  type        = string
  default     = "us-east-1"
}

variable "github_org" {
  description = "GitHub organization/user that owns the repository (used to scope the OIDC trust policy)."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (used to scope the OIDC trust policy)."
  type        = string
}

variable "github_owner_id" {
  description = <<-EOT
    Immutable numeric GitHub owner/org ID. Repositories created on or after
    2026-07-15 emit an immutable OIDC subject claim
    ("repo:<owner>@<owner_id>/<repo>@<repo_id>:...") instead of the
    plain-name format, so the trust policy must match on the ID-qualified
    form. Find it via: gh api repos/<org>/<repo> --jq '.owner.id'
  EOT
  type        = string
}

variable "github_repo_id" {
  description = <<-EOT
    Immutable numeric GitHub repository ID — see github_owner_id for why
    this is required. Find it via: gh api repos/<org>/<repo> --jq '.id'
  EOT
  type        = string
}
