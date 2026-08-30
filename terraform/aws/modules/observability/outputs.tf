output "namespace" {
  description = "Namespace the observability stack is installed into."
  value       = kubernetes_namespace_v1.this.metadata[0].name
}

output "grafana_service_name" {
  description = "Grafana Service name, for port-forward access: kubectl port-forward -n <namespace> svc/<this> 3000:80"
  value       = "${helm_release.kube_prometheus_stack.name}-grafana"
}

output "vpc_flow_log_group_name" {
  description = "CloudWatch Logs group receiving VPC Flow Logs, if enabled."
  value       = var.enable_vpc_flow_logs ? aws_cloudwatch_log_group.vpc_flow_logs[0].name : null
}

output "grafana_ingress_basic_auth_username" {
  value = var.enable_ingress ? "admin" : null
}

output "grafana_ingress_basic_auth_password" {
  description = "Basic-auth password in front of the Grafana Ingress - separate from Grafana's own login."
  value       = var.enable_ingress ? random_password.grafana_basic_auth[0].result : null
  sensitive   = true
}
