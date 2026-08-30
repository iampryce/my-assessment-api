output "argocd_namespace" {
  value = module.argocd.namespace
}

output "ingress_nginx_lb_hostname" {
  description = "AWS NLB hostname fronting ingress-nginx. Empty until the LoadBalancer finishes provisioning."
  value       = module.ingress_nginx.lb_hostname
}

output "cert_manager_cluster_issuer_name" {
  description = "ClusterIssuer name for the app's Ingress to reference via cert-manager.io/cluster-issuer."
  value       = module.cert_manager.cluster_issuer_name
}

output "dns_fqdn" {
  description = "The application hostname, once enable_dns is true and a real domain is supplied."
  value       = var.enable_dns ? module.dns[0].fqdn : null
}

output "dns_zone_name_servers" {
  description = "Add these as NS records for dns_zone_name at the registrar."
  value       = var.enable_dns ? module.dns[0].zone_name_servers : null
}

output "observability_namespace" {
  value = module.observability.namespace
}

output "grafana_service_name" {
  description = "Port-forward with: kubectl port-forward -n observability svc/<this> 3000:80"
  value       = module.observability.grafana_service_name
}
