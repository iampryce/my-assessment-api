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
    Huawei Cloud region. UNRESOLVED — must match the same region passed to
    the network and cce modules.
  EOT
  type        = string
}

variable "availability_zone" {
  description = "Primary availability zone for the RDS instance. UNRESOLVED for the same reason as the network module's variable of the same name."
  type        = string
}

variable "availability_zone_standby" {
  description = <<-EOT
    Standby availability zone, used only when enable_ha is true (a second
    AZ is required for a primary/standby pair). UNRESOLVED — left null
    until the region's AZ topology is confirmed against a live account.
  EOT
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC ID — pass module.network.vpc_id."
  type        = string
}

variable "subnet_id" {
  description = "RDS private subnet ID — pass module.network.rds_subnet_id."
  type        = string
}

variable "security_group_id" {
  description = "RDS security group ID — pass module.network.rds_security_group_id. Already restricted to CCE -> 5432 only; this module does not modify it."
  type        = string
}

variable "flavor" {
  description = <<-EOT
    RDS flavor code (e.g. "rds.pg.n1.large.2"). UNRESOLVED — placeholder
    only. Flavor availability is region-specific and has not been
    verified against a live account.
  EOT
  type        = string
}

variable "db_engine_version" {
  description = <<-EOT
    PostgreSQL engine version (e.g. "15"). UNRESOLVED — placeholder only.
    Supported versions are region/catalog-specific and have not been
    verified against a live account. Do not hardcode a guessed value.
  EOT
  type        = string
}

variable "enable_ha" {
  description = <<-EOT
    Whether to use a primary/standby HA topology (two availability zones)
    instead of a single instance. Only valid if the confirmed region has a
    second AZ available — UNVERIFIED without live account access.
  EOT
  type        = bool
  default     = false
}

variable "ha_replication_mode" {
  description = "PostgreSQL HA replication mode, only used when enable_ha is true. Valid values: \"async\" or \"sync\"."
  type        = string
  default     = "async"
}

variable "volume_type" {
  description = <<-EOT
    RDS storage volume type (e.g. "CLOUDSSD", "ULTRAHIGH"). UNVERIFIED
    against which volume types the target region actually offers.
  EOT
  type        = string
  default     = "CLOUDSSD"
}

variable "volume_size" {
  description = "RDS storage volume size in GB."
  type        = number
  default     = 40
}

variable "backup_keep_days" {
  description = "Automated backup retention in days (0-732)."
  type        = number
  default     = 7
}

variable "backup_start_time" {
  description = "Automated backup window, format \"hh:mm-HH:MM\"."
  type        = string
  default     = "02:00-03:00"
}

variable "rds_password" {
  description = <<-EOT
    RDS admin password. NEVER given a real value in any committed file —
    this must be supplied at plan/apply time via the TF_VAR_rds_password
    environment variable, sourced from Infisical. No default is provided
    deliberately, and this variable is marked sensitive so Terraform
    output never displays it in plan/apply logs.
  EOT
  type        = string
  sensitive   = true
}

variable "enterprise_project_id" {
  description = "Optional Huawei Cloud enterprise project ID. Left unset unless a real need is confirmed."
  type        = string
  default     = null
}
