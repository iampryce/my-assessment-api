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
  }
}

locals {
  acme_server_url = {
    staging    = "https://acme-staging-v02.api.letsencrypt.org/directory"
    production = "https://acme-v02.api.letsencrypt.org/directory"
  }[var.acme_server]

  issuer_name = "letsencrypt-${var.acme_server}"
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

resource "helm_release" "this" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.chart_version
  namespace  = kubernetes_namespace_v1.this.metadata[0].name

  set = [
    {
      name  = "crds.enabled"
      value = "true"
    },
  ]
}

# CRDs need a moment to register with the API server after the chart installs before a
# ClusterIssuer using them can be created - matches the same eventual-consistency handling already
# used elsewhere in this project (modules/eks's time_sleep after node group creation).
resource "time_sleep" "wait_for_crds" {
  depends_on      = [helm_release.this]
  create_duration = "30s"
}

# HTTP-01 challenge (not DNS-01): chosen because no CashOnRails-owned, Terraform-delegated Route53
# hosted zone exists yet (see modules/dns) - DNS-01 needs a real delegated zone plus a dedicated
# IRSA role scoped to route53:ChangeResourceRecordSets on it. HTTP-01 only needs the ingress
# already routing traffic (ingress-nginx), which this platform already has. Revisit DNS-01 once a
# real domain is delegated, if wildcard certificates become a requirement.
resource "kubernetes_manifest" "cluster_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = local.issuer_name
    }
    spec = {
      acme = {
        server = local.acme_server_url
        email  = var.acme_email
        privateKeySecretRef = {
          name = "${local.issuer_name}-account-key"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                ingressClassName = var.ingress_class_name
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [time_sleep.wait_for_crds]
}
