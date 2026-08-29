variable "environment" {
  description = "Environment name (e.g. \"staging\", \"production\")."
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be either \"staging\" or \"production\"."
  }
}

variable "hosted_zone_id" {
  description = <<-EOT
    Route53 hosted zone ID that owns the domain this environment's hostname is created under.
    No default: this project does not currently own a delegated domain. Do not point this at an
    unrelated pre-existing zone in the account - supply a real, CashOnRails-owned zone ID once one
    exists. Until then, leave this module uninstantiated (see runbook - this is an external
    prerequisite, not something to fake).
  EOT
  type        = string
}

variable "record_name" {
  description = "Fully-qualified hostname to create, e.g. \"api.staging.<domain>\" or \"api.<domain>\"."
  type        = string
}

variable "target_hostname" {
  description = "Hostname to point record_name at - pass module.ingress_nginx.lb_hostname."
  type        = string
}

variable "ttl" {
  description = "DNS record TTL in seconds."
  type        = number
  default     = 300
}
