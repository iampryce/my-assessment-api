variable "environment" {
  description = "Environment name used for tagging (e.g. \"staging\", \"production\")."
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be either \"staging\" or \"production\"."
  }
}

variable "namespace" {
  description = "Kubernetes namespace ingress-nginx is installed into."
  type        = string
  default     = "ingress-nginx"
}

variable "chart_version" {
  description = "ingress-nginx Helm chart version (kubernetes.github.io/ingress-nginx). Confirm current at apply time: helm search repo ingress-nginx/ingress-nginx --versions"
  type        = string
  default     = "4.11.3"
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the NLB's TLS listener (see modules/acm). Leave empty to keep the NLB as plain TCP passthrough, with nginx/cert-manager terminating TLS instead."
  type        = string
  default     = ""
}
