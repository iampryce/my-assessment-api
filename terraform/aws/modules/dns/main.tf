terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Dedicated zone per environment, isolated from whatever else lives on the parent domain and from
# the other environment's zone - no resource here depends on anything staging/production share.
resource "aws_route53_zone" "this" {
  name = var.zone_name
}

# CNAME rather than an ALIAS record: record_name is always a subdomain (api.staging.<domain> /
# api.<domain>), never the zone apex, so a CNAME is valid and avoids the extra `aws_lb` data-source
# lookup an ALIAS record would need just to resolve the NLB's own hosted-zone ID. Revisit if this
# ever needs to sit at an apex.
resource "aws_route53_record" "this" {
  zone_id = aws_route53_zone.this.zone_id
  name    = var.record_name
  type    = "CNAME"
  ttl     = var.ttl
  records = [var.target_hostname]
}
