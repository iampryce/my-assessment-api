variable "environment" {
  description = "Environment name used for tagging (e.g. \"staging\", \"production\")."
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be either \"staging\" or \"production\"."
  }
}

variable "zone_id" {
  description = "Route53 hosted zone ID to create DNS validation records in - pass module.dns[0].zone_id."
  type        = string
}

variable "domain_name" {
  description = "Zone name the certificate is issued for, e.g. \"staging.cashonrails.example.com\"."
  type        = string
}

variable "subject_alternative_names" {
  description = "Extra hostnames the certificate covers. Defaults to a wildcard over domain_name so one cert serves every subdomain behind the shared NLB (api, grafana, argocd)."
  type        = list(string)
  default     = null
}
