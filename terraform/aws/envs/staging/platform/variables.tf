variable "aws_region" {
  description = "AWS region the staging cluster lives in."
  type        = string
  default     = "us-east-1"
}

variable "eks_cluster_name" {
  description = "Name of the staging EKS cluster."
  type        = string
  default     = "cashonrails-aws-staging"
}

variable "acme_email" {
  description = "Contact email registered with Let's Encrypt. Required - no default."
  type        = string
}

variable "enable_dns" {
  description = <<-EOT
    Whether to create the DNS record for this environment. Defaults to false: this project does
    not currently own a delegated domain (see modules/dns). Set to true, and supply
    dns_hosted_zone_id/dns_record_name, only once a real CashOnRails-owned zone exists - never
    point this at an unrelated pre-existing zone in the account.
  EOT
  type        = bool
  default     = false
}

variable "dns_hosted_zone_id" {
  description = "Route53 hosted zone ID - required only if enable_dns is true."
  type        = string
  default     = ""
}

variable "dns_record_name" {
  description = "Hostname to create, e.g. \"api.staging.<domain>\" - required only if enable_dns is true."
  type        = string
  default     = ""
}
