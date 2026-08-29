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

# Installed via the platform-bootstrap identity (cluster-scoped EKS access entry) - see
# modules/eks. Never exposed publicly: server.service.type stays ClusterIP, reached only through
# the SSM tunnel (kubectl port-forward/proxy), same as the Kubernetes API itself.
resource "helm_release" "this" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version
  namespace  = kubernetes_namespace_v1.this.metadata[0].name

  set = [
    {
      name  = "crds.install"
      value = "true"
    },
    {
      name  = "server.service.type"
      value = "ClusterIP"
    },
    # TLS is terminated by argocd-server itself for the (internal-only) API/UI; unrelated to the
    # application's own TLS via cert-manager/Let's Encrypt.
    {
      name  = "configs.params.server\\.insecure"
      value = "false"
    },
    {
      name  = "redis-ha.enabled"
      value = "false"
    },
  ]
}
