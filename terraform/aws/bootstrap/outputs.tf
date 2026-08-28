output "state_bucket_name" {
  description = "Name of the Terraform state bucket. Needed for backend-config when running `terraform init` in terraform/aws/envs/*."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "state_bucket_arn" {
  description = "ARN of the Terraform state bucket."
  value       = aws_s3_bucket.terraform_state.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider registered in this AWS account."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "github_plan_role_arn" {
  description = "IAM role ARN for GitHub Actions to assume on pull_request workflows (read-only)."
  value       = aws_iam_role.github_plan.arn
}

output "github_apply_role_arn" {
  description = "IAM role ARN for GitHub Actions to assume on staging/production environment-protected workflows (read-write, scoped)."
  value       = aws_iam_role.github_apply.arn
}
