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
    the network module. See the network module's own variable description
    for why no default is provided.
  EOT
  type        = string
}

variable "availability_zone" {
  description = <<-EOT
    Availability zone for the node pool (and, when enable_ha_control_plane
    is false, implicitly for the single-master control plane too).
    UNRESOLVED for the same reason as the network module's variable of the
    same name.
  EOT
  type        = string
}

variable "vpc_id" {
  description = "VPC ID — pass module.network.vpc_id."
  type        = string
}

variable "subnet_id" {
  description = "CCE private subnet ID — pass module.network.cce_subnet_id."
  type        = string
}

variable "security_group_id" {
  description = "CCE security group ID — pass module.network.cce_security_group_id."
  type        = string
}

variable "cluster_version" {
  description = <<-EOT
    Kubernetes version (e.g. "v1.29"). Left null by default so the provider
    defaults to Huawei's current latest supported version rather than a
    hardcoded guess — CCE only ever offers odd major versions and rotates
    which ones are current. Confirm against the live account (or
    `data.huaweicloud_cce_cluster_versions`) before pinning a specific
    value for real use.
  EOT
  type        = string
  default     = null
}

variable "enable_ha_control_plane" {
  description = <<-EOT
    Whether to use an HA (3-master, multi-AZ) control plane (flavor
    "cce.s2.small", multi_az = true) instead of a single-master control
    plane (flavor "cce.s1.small"). HA is only meaningful if the target
    region/project actually has >= 3 availability zones available — this
    has not been verified against a live account. Confirm AZ availability
    before setting this true.
  EOT
  type        = bool
  default     = false
}

variable "node_flavor_id" {
  description = <<-EOT
    ECS flavor ID for worker nodes (e.g. "s6.large.2"). UNRESOLVED —
    placeholder only. Node flavor availability is region-specific and has
    not been verified against a live account.
  EOT
  type        = string
}

variable "node_count" {
  description = "Number of worker nodes to create initially."
  type        = number
  default     = 2
}

variable "node_root_volume_size" {
  description = "Root volume size in GB for worker nodes."
  type        = number
  default     = 40
}

variable "node_root_volume_type" {
  description = <<-EOT
    Root volume type for worker nodes (e.g. "SAS"). UNVERIFIED against
    which volume types the target region actually offers — confirm before
    relying on this value.
  EOT
  type        = string
  default     = "SAS"
}

variable "node_os" {
  description = <<-EOT
    Worker node OS image (e.g. "EulerOS 2.9"). UNVERIFIED against which
    images the target region actually offers — confirm before relying on
    this value.
  EOT
  type        = string
  default     = "EulerOS 2.9"
}

variable "node_key_pair" {
  description = <<-EOT
    Name of a pre-existing Huawei Cloud SSH key pair for node login.
    UNRESOLVED — no default is provided. The Huawei Cloud API requires
    some login credential (key pair or password) to create a node even
    though this architecture does not plan to expose SSH: the CCE security
    group deliberately does not open port 22 (see the network module).
    Supply a real key pair name before apply — the credential will exist
    but remain network-unreachable under the current security group rules.
  EOT
  type        = string
}

variable "enterprise_project_id" {
  description = "Optional Huawei Cloud enterprise project ID. Left unset unless a real need is confirmed."
  type        = string
  default     = null
}
