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

variable "cluster_version" {
  description = "Kubernetes version for the CCE cluster. Left null to let the provider default to Huawei's current latest supported version — do not hardcode a guessed version string."
  type        = string
  default     = null
}

variable "node_flavor_id" {
  description = "UNRESOLVED — ECS flavor ID for staging worker nodes. Placeholder only; confirm against the live account before apply."
  type        = string
}

variable "node_key_pair" {
  description = "UNRESOLVED — name of a pre-existing Huawei Cloud SSH key pair for staging node login. No default; confirm before apply."
  type        = string
}

variable "node_count" {
  description = "Number of staging worker nodes."
  type        = number
  default     = 2
}

variable "rds_flavor" {
  description = "UNRESOLVED — RDS flavor code for staging. Placeholder only; confirm against the live account/region catalog before apply."
  type        = string
}

variable "rds_engine_version" {
  description = "UNRESOLVED — PostgreSQL engine version for staging. Placeholder only; confirm against the live account/region catalog before apply."
  type        = string
}

variable "rds_volume_type" {
  description = "RDS storage volume type. Cost-conscious default for staging — confirm against the region's actual offered volume types before apply."
  type        = string
  default     = "CLOUDSSD"
}

variable "rds_volume_size" {
  description = "RDS storage volume size in GB for staging."
  type        = number
  default     = 40
}

variable "rds_backup_keep_days" {
  description = "Automated backup retention in days. Cost-conscious (short) default for staging."
  type        = number
  default     = 7
}

variable "rds_password" {
  description = <<-EOT
    RDS admin password. NEVER set a real value here or in
    terraform.tfvars — supply it at apply time via the TF_VAR_rds_password
    environment variable, sourced from Infisical. No default is provided
    deliberately.
  EOT
  type        = string
  sensitive   = true
}
