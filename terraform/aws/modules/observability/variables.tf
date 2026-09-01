variable "environment" {
  description = "Environment name (e.g. \"staging\", \"production\")."
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be either \"staging\" or \"production\"."
  }
}

variable "namespace" {
  description = "Kubernetes namespace the observability stack is installed into."
  type        = string
  default     = "observability"
}

variable "kube_prometheus_stack_chart_version" {
  description = "kube-prometheus-stack Helm chart version (prometheus-community.github.io/helm-charts). Confirm current at apply time: helm search repo prometheus-community/kube-prometheus-stack --versions"
  type        = string
  default     = "65.5.1"
}

variable "loki_stack_chart_version" {
  description = "loki-stack Helm chart version (grafana.github.io/helm-charts). Confirm current at apply time: helm search repo grafana/loki-stack --versions"
  type        = string
  default     = "2.10.2"
}

variable "metrics_retention" {
  description = "Prometheus metrics retention window. Kept short deliberately - see main.tf cost note."
  type        = string
  default     = "6h"
}

variable "logs_retention_hours" {
  description = "Loki log retention, in hours. Kept short deliberately - see main.tf cost note."
  type        = number
  default     = 24
}

variable "enable_vpc_flow_logs" {
  description = "Whether to enable VPC Flow Logs to CloudWatch Logs for this environment's VPC."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "CloudWatch Logs retention for VPC Flow Logs, in days. Bounds cost for a validation environment."
  type        = number
  default     = 7
}

variable "enable_ingress" {
  description = "Whether to expose Grafana via a public, basic-auth-protected Ingress instead of SSM-tunnel-only access."
  type        = bool
  default     = false
}

variable "ingress_host" {
  description = "Hostname for the Grafana Ingress - required only if enable_ingress is true."
  type        = string
  default     = ""
}

variable "cluster_issuer_name" {
  description = "cert-manager ClusterIssuer name for the Ingress TLS - required only if enable_ingress is true and acm_tls_termination is false."
  type        = string
  default     = ""
}

variable "acm_tls_termination" {
  description = "true once the shared NLB terminates TLS with an ACM cert (see modules/acm) - skips the cert-manager annotation/tls block on Grafana's Ingress, since nginx then only ever sees plain HTTP."
  type        = bool
  default     = false
}

variable "ingress_class_name" {
  description = "IngressClass routing traffic to the Ingress."
  type        = string
  default     = "nginx"
}

variable "slack_webhook_url" {
  description = "Slack Incoming Webhook URL for Alertmanager notifications. Leave empty to skip wiring Slack alerting entirely."
  type        = string
  default     = ""
  sensitive   = true
}

variable "slack_channel" {
  description = "Slack channel Alertmanager posts to - required only if slack_webhook_url is set."
  type        = string
  default     = "#alerts"
}
