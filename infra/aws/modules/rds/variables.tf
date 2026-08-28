variable "environment" {
  description = "Environment name used for resource naming/tagging (e.g. \"staging\", \"production\")."
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be either \"staging\" or \"production\"."
  }
}

variable "vpc_id" {
  description = "VPC ID — pass module.network.vpc_id."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the DB subnet group — pass module.network.private_subnet_ids."
  type        = list(string)
}

variable "node_security_group_id" {
  description = "EKS node security group ID — pass module.eks.node_security_group_id. RDS ingress is restricted to this security group on 5432 only."
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "allocated_storage" {
  description = "RDS allocated storage in GB."
  type        = number
}

variable "multi_az" {
  description = "Whether RDS uses a Multi-AZ deployment. Defaults to false (cost-conscious) — available per environment, not yet differentiated between staging and production."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Automated backup retention in days. Defaults to 1 (cost-conscious, minimal) — available per environment, not yet differentiated between staging and production."
  type        = number
  default     = 1
}
