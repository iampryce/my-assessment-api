output "namespace" {
  description = "Namespace Argo CD is installed into."
  value       = kubernetes_namespace_v1.this.metadata[0].name
}

output "release_name" {
  description = "Helm release name."
  value       = helm_release.this.name
}

output "release_status" {
  description = "Helm release status as last observed by Terraform."
  value       = helm_release.this.status
}

output "ingress_basic_auth_username" {
  value = var.enable_ingress ? "admin" : null
}

output "ingress_basic_auth_password" {
  description = "Basic-auth password in front of the Argo CD Ingress - separate from Argo CD's own admin login."
  value       = var.enable_ingress ? random_password.basic_auth[0].result : null
  sensitive   = true
}
