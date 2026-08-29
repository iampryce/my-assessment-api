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

output "github_app_cicd_role_arn" {
  description = "IAM role ARN for the application CI/CD workflow (ECR push + EKS deploy, separate from the Terraform apply role)."
  value       = aws_iam_role.github_app_cicd.arn
}

output "github_platform_bootstrap_role_arn" {
  description = "IAM role ARN for installing/upgrading the cluster platform layer (Argo CD, ingress-nginx, cert-manager). Gated behind the \"platform\" GitHub Environment; separate from both the infra-apply and app-cicd roles."
  value       = aws_iam_role.github_platform_bootstrap.arn
}
