module "argocd" {
  source = "../../../modules/argocd"

  environment         = "production"
  enable_ingress      = var.enable_admin_ingress
  ingress_host        = var.enable_admin_ingress ? "argocd.${var.dns_zone_name}" : ""
  cluster_issuer_name = var.enable_admin_ingress ? module.cert_manager.cluster_issuer_name : ""
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

  environment         = "production"
  enable_ingress      = var.enable_admin_ingress
  ingress_host        = var.enable_admin_ingress ? "grafana.${var.dns_zone_name}" : ""
  cluster_issuer_name = var.enable_admin_ingress ? module.cert_manager.cluster_issuer_name : ""
}

# Deliberately not instantiated by default - see enable_dns. Creates its own dedicated zone.
# enable_admin_ingress requires enable_dns=true too - argocd/grafana hostnames live in the same zone.
module "dns" {
  count  = var.enable_dns ? 1 : 0
  source = "../../../modules/dns"

  environment     = "production"
  zone_name       = var.dns_zone_name
  record_name     = var.dns_record_name
  target_hostname = module.ingress_nginx.lb_hostname

  additional_records = var.enable_admin_ingress ? {
    argocd  = module.ingress_nginx.lb_hostname
    grafana = module.ingress_nginx.lb_hostname
  } : {}
}
