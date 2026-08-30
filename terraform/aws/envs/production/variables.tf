variable "aws_region" {
  description = <<-EOT
    AWS region for this temporary validation environment. Unlike the
    Huawei environments, this is not constrained by a data-residency
    requirement (AWS is functional validation only, per the approved
    architecture) — any region with EKS + RDS PostgreSQL available works.
  EOT
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the production validation VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across. Two is enough to satisfy \"multiple AZs\" without over-provisioning for a validation environment."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version. A recent stable version is set as a default; confirm it is still supported by EKS at apply time."
  type        = string
  default     = "1.31"
}

variable "node_instance_type" {
  description = "EC2 instance type for the EKS managed node group. Same tier as staging — not yet differentiated, this environment is not being deployed."
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired worker node count."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum worker node count."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum worker node count."
  type        = number
  default     = 3
}

variable "rds_engine_version" {
  description = "PostgreSQL engine version for RDS."
  type        = string
  default     = "16"
}

variable "rds_instance_class" {
  description = "RDS instance class. Same tier as staging — not yet differentiated, this environment is not being deployed."
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB."
  type        = number
  default     = 20
}

variable "rds_multi_az" {
  description = "Whether RDS uses a Multi-AZ deployment. Left false (same as staging) for now — a real candidate for tightening once this environment is actually prepared for deployment."
  type        = bool
  default     = false
}

variable "rds_backup_retention_period" {
  description = "Automated backup retention in days. Left at 1 (same as staging) for now — a real candidate for tightening once this environment is actually prepared for deployment."
  type        = number
  default     = 1
}

variable "cicd_ssm_target_ami_id" {
  description = "Amazon Linux 2023 x86_64 AMI ID for the CI/CD SSM deployment bridge. A recent AMI is set as a default; confirm it is still current at apply time with: aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 --query Parameter.Value --output text --region us-east-1"
  type        = string
  default     = "ami-0332d564d76dbd8d6"
}

variable "admin_principal_arns" {
  description = "IAM user/role ARNs to grant standing cluster-wide EKS edit access. Empty by default; set via local terraform.tfvars, not CI."
  type        = list(string)
  default     = []
}
