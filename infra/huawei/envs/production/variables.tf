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

variable "cluster_version" {
  description = "Kubernetes version for the CCE cluster. Left null to let the provider default to Huawei's current latest supported version — do not hardcode a guessed version string."
  type        = string
  default     = null
}

variable "enable_ha_control_plane" {
  description = <<-EOT
    Whether production uses an HA (3-master, multi-AZ) control plane.
    Defaults to true per the approved architecture, but this is only
    valid if the confirmed region/project actually has >= 3 availability
    zones — UNVERIFIED without live account access. Set this to false in
    terraform.tfvars if the confirmed region cannot support HA, and
    document why.
  EOT
  type        = bool
  default     = true
}

variable "node_flavor_id" {
  description = "UNRESOLVED — ECS flavor ID for production worker nodes. Placeholder only; confirm against the live account before apply."
  type        = string
}

variable "node_key_pair" {
  description = "UNRESOLVED — name of a pre-existing Huawei Cloud SSH key pair for production node login. No default; confirm before apply."
  type        = string
}

variable "node_count" {
  description = "Number of production worker nodes. Starts at 2; raise to 3 later if desired — no code change required."
  type        = number
  default     = 2
}

variable "rds_flavor" {
  description = "UNRESOLVED — RDS flavor code for production. Placeholder only; confirm against the live account/region catalog before apply."
  type        = string
}

variable "rds_engine_version" {
  description = "UNRESOLVED — PostgreSQL engine version for production. Placeholder only; confirm against the live account/region catalog before apply."
  type        = string
}

variable "rds_enable_ha" {
  description = <<-EOT
    Whether production RDS uses a primary/standby HA topology. Defaults to
    true per the approved architecture ("stronger availability/recovery
    settings where supported"), but this is only valid if the confirmed
    region/project has a second availability zone available for the
    standby — UNVERIFIED without live account access. Set to false in
    terraform.tfvars if the confirmed region cannot support it, and
    document why.
  EOT
  type        = bool
  default     = true
}

variable "rds_availability_zone_standby" {
  description = "UNRESOLVED — standby availability zone for production RDS HA. Required only when rds_enable_ha is true; placeholder until the region's AZ topology is confirmed."
  type        = string
  default     = null
}

variable "rds_ha_replication_mode" {
  description = "PostgreSQL HA replication mode: \"async\" or \"sync\". Defaults to async; switch to sync for stronger durability if confirmed acceptable for production (higher write latency)."
  type        = string
  default     = "async"
}

variable "rds_volume_type" {
  description = "RDS storage volume type for production. UNVERIFIED against the region's actual offered volume types — a higher-durability tier than staging's default, pending confirmation."
  type        = string
  default     = "ULTRAHIGH"
}

variable "rds_volume_size" {
  description = "RDS storage volume size in GB for production."
  type        = number
  default     = 100
}

variable "rds_backup_keep_days" {
  description = "Automated backup retention in days. Longer default than staging (\"stronger recovery settings\")."
  type        = number
  default     = 30
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
