variable "environment" {
  description = "Environment name used for tagging (e.g. \"staging\", \"production\")."
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be either \"staging\" or \"production\"."
  }
}

variable "namespace" {
  description = "Kubernetes namespace cert-manager is installed into."
  type        = string
  default     = "cert-manager"
}

variable "chart_version" {
  description = "cert-manager Helm chart version (charts.jetstack.io). Confirm current at apply time: helm search repo jetstack/cert-manager --versions"
  type        = string
  default     = "v1.16.2"
}

variable "acme_email" {
  description = "Contact email registered with Let's Encrypt for expiry/abuse notices. Required - no default, this is a real operational input, not a placeholder."
  type        = string
}

variable "acme_server" {
  description = <<-EOT
    Which Let's Encrypt ACME endpoint this environment's ClusterIssuer points at.
    Use "staging" in the AWS staging environment (untrusted certs, no rate-limit risk while
    iterating) and "production" only in the AWS production environment.
  EOT
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.acme_server)
    error_message = "acme_server must be either \"staging\" or \"production\"."
  }
}

variable "ingress_class_name" {
  description = "IngressClass the HTTP-01 solver routes challenge traffic through."
  type        = string
  default     = "nginx"
}
