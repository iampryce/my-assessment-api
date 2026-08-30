module "argocd" {
  source = "../../../modules/argocd"

  environment = "staging"
}

module "ingress_nginx" {
  source = "../../../modules/ingress-nginx"

  environment = "staging"
}

module "cert_manager" {
  source = "../../../modules/cert-manager"

  environment = "staging"
  acme_email  = var.acme_email
  acme_server = "staging" # Let's Encrypt's staging ACME endpoint - deliberately not "production" here, see modules/cert-manager
}

module "observability" {
  source = "../../../modules/observability"

  environment = "staging"
}

# Deliberately not instantiated by default - see enable_dns. Creates its own dedicated zone.
module "dns" {
  count  = var.enable_dns ? 1 : 0
  source = "../../../modules/dns"

  environment     = "staging"
  zone_name       = var.dns_zone_name
  record_name     = var.dns_record_name
  target_hostname = module.ingress_nginx.lb_hostname
}
