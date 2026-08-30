variable "aws_region" {
  description = "AWS region the production cluster lives in."
  type        = string
  default     = "us-east-1"
}

variable "eks_cluster_name" {
  description = "Name of the production EKS cluster."
  type        = string
  default     = "cashonrails-aws-production"
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
  description = "Subdomain to create a dedicated Route53 zone for, e.g. \"cashonrails.example.com\" - required only if enable_dns is true."
  type        = string
  default     = ""
}

variable "dns_record_name" {
  description = "Hostname to create inside the zone, e.g. \"api.<domain>\" - required only if enable_dns is true."
  type        = string
  default     = ""
}

variable "enable_admin_ingress" {
  description = "Whether to expose Argo CD and Grafana via public, basic-auth-protected Ingresses. Requires enable_dns=true too - their hostnames live in the same zone."
  type        = bool
  default     = false
}
