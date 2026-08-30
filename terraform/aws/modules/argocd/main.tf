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
    time = {
      source = "hashicorp/time"
    }
    random = {
      source = "hashicorp/random"
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

# Installed via the platform-bootstrap identity (cluster-scoped EKS access entry) - see modules/eks.
# ClusterIP by default (SSM-tunnel-only access); enable_ingress below adds a basic-auth-protected
# public Ingress on top without changing this Service.
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

# Same eventual-consistency handling as modules/cert-manager: kubernetes_manifest computes the
# Application CRD's schema at plan time, so a fresh terraform apply must run after the CRDs
# actually exist (see platform-addons.yml's two-phase apply for this job).
resource "time_sleep" "wait_for_crds" {
  depends_on      = [helm_release.this]
  create_duration = "30s"
}

# Tells Argo CD to sync deploy/helm/cashonrails-api into this environment's cluster - without
# this, Argo CD is installed but manages nothing, and the app's own namespace never gets created.
resource "kubernetes_manifest" "cashonrails_api" {
  manifest = yamldecode(file("${path.module}/../../../../deploy/argocd-apps/${var.environment}/application.yaml"))

  depends_on = [time_sleep.wait_for_crds]
}

# Second auth layer in front of Argo CD's own login - random per apply, never stored in git.
resource "random_password" "basic_auth" {
  count   = var.enable_ingress ? 1 : 0
  length  = 24
  special = false
}

resource "kubernetes_secret_v1" "basic_auth" {
  count = var.enable_ingress ? 1 : 0

  metadata {
    name      = "argocd-basic-auth"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  data = {
    auth = "admin:${bcrypt(random_password.basic_auth[0].result)}"
  }
}

# server.insecure=false above means argocd-server serves its own TLS internally - backend-protocol
# HTTPS tells nginx to connect over TLS to it, while cert-manager terminates the public-facing TLS.
resource "kubernetes_ingress_v1" "this" {
  count = var.enable_ingress ? 1 : 0

  metadata {
    name      = "argocd-server"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"               = var.cluster_issuer_name
      "nginx.ingress.kubernetes.io/auth-type"        = "basic"
      "nginx.ingress.kubernetes.io/auth-secret"      = kubernetes_secret_v1.basic_auth[0].metadata[0].name
      "nginx.ingress.kubernetes.io/auth-secret-type" = "auth-file"
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
    }
  }

  spec {
    ingress_class_name = var.ingress_class_name

    tls {
      hosts       = [var.ingress_host]
      secret_name = "argocd-ingress-tls"
    }

    rule {
      host = var.ingress_host
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
              port {
                name = "https"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.this]
}
