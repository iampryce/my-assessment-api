terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "environment"                  = var.environment
    }
  }
}

# Uses EKS's built-in in-tree AWS cloud provider integration for Service type=LoadBalancer,
# provisioning a single Network Load Balancer - not the separate AWS Load Balancer Controller.
# Deliberate scoping decision: our needs (one NLB routing to ingress-nginx, no WAF/multi-ingress-
# class/IP-target-type requirements) don't justify a second controller and its own IRSA role. The
# in-tree path needs no additional customer-managed IAM - EKS's control plane role already covers
# it. Revisit if requirements grow beyond what this supports.
#
# This is the only LoadBalancer in the platform - Argo CD stays ClusterIP-only.
resource "helm_release" "this" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.chart_version
  namespace  = kubernetes_namespace_v1.this.metadata[0].name

  set = concat([
    {
      name  = "controller.service.type"
      value = "LoadBalancer"
    },
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
      value = "nlb"
    },
    # Preserves client source IP (required for accurate access logs/rate limiting later) - trades
    # away even node-level load spreading, acceptable at this traffic scale.
    {
      name  = "controller.service.externalTrafficPolicy"
      value = "Local"
    },
    # Required so Ingress .status.loadBalancer is populated with the NLB hostname - the DNS
    # module reads this to create the CNAME record.
    {
      name  = "controller.publishService.enabled"
      value = "true"
    },
    {
      name  = "controller.ingressClassResource.name"
      value = "nginx"
    },
    {
      name  = "controller.ingressClassResource.default"
      value = "true"
    },
    ],
    # NLB terminates TLS itself with this ACM cert when set - traffic then reaches nginx as plain
    # HTTP, so any Ingress relying on it must drop its cert-manager annotation/tls block (see
    # deploy/helm/cashonrails-api's ingress.acmTlsTermination).
    var.certificate_arn != "" ? [
      {
        name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-cert"
        value = var.certificate_arn
      },
      {
        name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-ports"
        value = "443"
      },
    ] : []
  )
}
