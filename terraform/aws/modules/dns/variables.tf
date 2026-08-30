variable "environment" {
  description = "Environment name (e.g. \"staging\", \"production\")."
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be either \"staging\" or \"production\"."
  }
}

variable "zone_name" {
  description = "Subdomain to create a dedicated Route53 zone for, e.g. \"staging.cashonrails.example.com\". This module creates the zone itself - no default, this is a real domain you control, not a placeholder. Delegate it at the registrar using this module's zone_name_servers output."
  type        = string
}

variable "record_name" {
  description = "Fully-qualified hostname to create inside the zone, e.g. \"api.staging.<domain>\". Must be zone_name itself or a subdomain of it - not the zone's own apex, since a CNAME can't share a name with the zone's NS/SOA records."
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
