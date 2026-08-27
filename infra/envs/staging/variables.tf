variable "region" {
  description = <<-EOT
    Huawei Cloud region.

    UNRESOLVED: the Terraform-usable identifier for Huawei Cloud's Nigeria
    region has not been confirmed against a live account. Set explicitly in
    terraform.tfvars once verified — no default is provided deliberately.
  EOT
  type        = string
}

variable "availability_zone" {
  description = "Availability zone for subnet placement. Depends on the region decision above; unresolved for the same reason."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the staging VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "cce_subnet_cidr" {
  description = "CIDR block for the staging CCE private subnet."
  type        = string
  default     = "10.10.1.0/24"
}

variable "rds_subnet_cidr" {
  description = "CIDR block for the staging RDS private subnet."
  type        = string
  default     = "10.10.2.0/24"
}

variable "enterprise_project_id" {
  description = "Optional Huawei Cloud enterprise project ID for cost grouping."
  type        = string
  default     = null
}
