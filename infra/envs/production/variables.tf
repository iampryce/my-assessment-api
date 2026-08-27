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
  description = "CIDR block for the production VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "cce_subnet_cidr" {
  description = "CIDR block for the production CCE private subnet."
  type        = string
  default     = "10.20.1.0/24"
}

variable "rds_subnet_cidr" {
  description = "CIDR block for the production RDS private subnet."
  type        = string
  default     = "10.20.2.0/24"
}

variable "enterprise_project_id" {
  description = "Optional Huawei Cloud enterprise project ID for cost grouping."
  type        = string
  default     = null
}
