variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name to grant access to."
  type        = string
  default     = "cashonrails-aws-staging"
}

variable "admin_principal_arns" {
  description = "IAM user/role ARNs to grant standing cluster-wide EKS edit access, e.g. for personal admin use. Empty by default - not tied to any specific identity, so this stays reusable. Apply this root locally only, never via CI - that's the entire reason it's split out from module.eks."
  type        = list(string)
  default     = []
}
