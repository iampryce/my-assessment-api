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

# Deliberately not instantiated by default - see enable_dns. No CashOnRails-owned domain exists
# yet; this is an external prerequisite (see the final report), not something to fake.
module "dns" {
  count  = var.enable_dns ? 1 : 0
  source = "../../../modules/dns"

  environment     = "production"
  hosted_zone_id  = var.dns_hosted_zone_id
  record_name     = var.dns_record_name
  target_hostname = module.ingress_nginx.lb_hostname
}
