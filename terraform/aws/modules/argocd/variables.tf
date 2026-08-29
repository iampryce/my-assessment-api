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
