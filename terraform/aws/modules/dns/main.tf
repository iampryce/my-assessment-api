terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# CNAME rather than an ALIAS record: record_name is always a subdomain (api.staging.<domain> /
# api.<domain>), never the zone apex, so a CNAME is valid and avoids the extra `aws_lb` data-source
# lookup an ALIAS record would need just to resolve the NLB's own hosted-zone ID. Revisit if this
# ever needs to sit at an apex.
resource "aws_route53_record" "this" {
  zone_id = var.hosted_zone_id
  name    = var.record_name
  type    = "CNAME"
  ttl     = var.ttl
  records = [var.target_hostname]
}
