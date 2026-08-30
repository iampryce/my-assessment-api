module "argocd" {
  source = "../../../modules/argocd"

  environment = "production"
}

module "ingress_nginx" {
  source = "../../../modules/ingress-nginx"

  environment = "production"
}

module "cert_manager" {
  source = "../../../modules/cert-manager"

  environment = "production"
  acme_email  = var.acme_email
  acme_server = "production"
}

module "observability" {
  source = "../../../modules/observability"

  environment = "production"
}

# Deliberately not instantiated by default - see enable_dns. Creates its own dedicated zone.
module "dns" {
  count  = var.enable_dns ? 1 : 0
  source = "../../../modules/dns"

  environment     = "production"
  zone_name       = var.dns_zone_name
  record_name     = var.dns_record_name
  target_hostname = module.ingress_nginx.lb_hostname
}
