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
