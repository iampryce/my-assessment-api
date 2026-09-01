variable "environment" {
  description = "Environment name used for tagging (e.g. \"staging\", \"production\")."
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be either \"staging\" or \"production\"."
  }
}

variable "namespace" {
  description = "Kubernetes namespace Argo CD is installed into."
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "argo-cd Helm chart version (argoproj.github.io/argo-helm). Confirm this is still current at apply time: helm search repo argo/argo-cd --versions"
  type        = string
  default     = "7.7.11"
}

variable "enable_ingress" {
  description = "Whether to expose Argo CD via a public, basic-auth-protected Ingress instead of SSM-tunnel-only access."
  type        = bool
  default     = false
}

variable "ingress_host" {
  description = "Hostname for the Argo CD Ingress - required only if enable_ingress is true."
  type        = string
  default     = ""
}

variable "cluster_issuer_name" {
  description = "cert-manager ClusterIssuer name for the Ingress TLS - required only if enable_ingress is true and acm_tls_termination is false."
  type        = string
  default     = ""
}

variable "acm_tls_termination" {
  description = "true once the shared NLB terminates TLS with an ACM cert (see modules/acm) - skips the cert-manager annotation/tls block on this Ingress, since nginx then only ever sees plain HTTP."
  type        = bool
  default     = false
}

variable "ingress_class_name" {
  description = "IngressClass routing traffic to the Ingress."
  type        = string
  default     = "nginx"
}
