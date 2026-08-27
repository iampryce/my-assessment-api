variable "environment" {
  description = "Environment name used for resource naming (e.g. \"staging\", \"production\")."
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be either \"staging\" or \"production\"."
  }
}

variable "region" {
  description = <<-EOT
    Huawei Cloud region to deploy into.

    UNRESOLVED: the Terraform-usable region identifier for Huawei Cloud's
    Nigeria region has not been verified against a live account. Do not
    hardcode a value here or default it — callers must supply this
    explicitly per environment until the region is confirmed.
  EOT
  type        = string
}

variable "availability_zone" {
  description = <<-EOT
    Availability zone used for subnet placement.

    UNRESOLVED for the same reason as var.region: AZ naming depends on
    which region is ultimately confirmed for use. Supply explicitly per
    environment once known.
  EOT
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the environment's VPC."
  type        = string
}

variable "cce_subnet_cidr" {
  description = "CIDR block for the private subnet used by CCE nodes."
  type        = string
}

variable "rds_subnet_cidr" {
  description = "CIDR block for the private subnet used by RDS."
  type        = string
}

variable "nat_gateway_spec" {
  description = "NAT gateway spec size: \"1\" (Small), \"2\" (Medium), \"3\" (Large), \"4\" (Extra-large)."
  type        = string
  default     = "1"
}

variable "enterprise_project_id" {
  description = "Optional Huawei Cloud enterprise project ID for cost grouping. Left unset unless a real need is confirmed."
  type        = string
  default     = null
}
