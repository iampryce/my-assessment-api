# Reads the Service's runtime status (populated by the AWS cloud provider once the NLB is
# provisioned) so the DNS module can point a record at it without a human copying a hostname by
# hand. This data source only resolves successfully after the LoadBalancer is actually up - that
# is an expected, explicit ordering dependency (ingress-nginx must be healthy before DNS applies).
data "kubernetes_service_v1" "controller" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  depends_on = [helm_release.this]
}

output "namespace" {
  description = "Namespace ingress-nginx is installed into."
  value       = kubernetes_namespace_v1.this.metadata[0].name
}

output "lb_hostname" {
  description = "Hostname of the AWS NLB provisioned for the ingress-nginx controller Service. Empty until the LoadBalancer has finished provisioning - re-run `terraform apply` (or `refresh`) after ingress-nginx is confirmed healthy if this is blank."
  value       = try(data.kubernetes_service_v1.controller.status[0].load_balancer[0].ingress[0].hostname, "")
}
