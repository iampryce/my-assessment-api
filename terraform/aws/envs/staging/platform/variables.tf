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
  description = "Whether to create this environment's dedicated DNS zone + record. Defaults to false until dns_zone_name/dns_record_name point at a domain you actually control."
  type        = bool
  default     = false
}

variable "dns_zone_name" {
  description = "Subdomain to create a dedicated Route53 zone for, e.g. \"staging.cashonrails.example.com\" - required only if enable_dns is true."
  type        = string
  default     = ""
}

variable "dns_record_name" {
  description = "Hostname to create inside the zone, e.g. \"api.staging.<domain>\" - required only if enable_dns is true."
  type        = string
  default     = ""
}
