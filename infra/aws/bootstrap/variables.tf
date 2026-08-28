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
