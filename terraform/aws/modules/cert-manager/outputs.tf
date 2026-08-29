output "namespace" {
  description = "Namespace cert-manager is installed into."
  value       = kubernetes_namespace_v1.this.metadata[0].name
}

output "cluster_issuer_name" {
  description = "Name of the ClusterIssuer the application's Ingress/Certificate resources should reference (cert-manager.io/cluster-issuer annotation)."
  value       = local.issuer_name
}
