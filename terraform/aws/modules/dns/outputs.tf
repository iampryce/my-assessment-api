output "fqdn" {
  description = "The fully-qualified hostname created."
  value       = aws_route53_record.this.fqdn
}

output "zone_id" {
  description = "Route53 zone ID for zone_name."
  value       = aws_route53_zone.this.zone_id
}

output "zone_name_servers" {
  description = "Delegate zone_name by adding these as NS records for it at the registrar."
  value       = aws_route53_zone.this.name_servers
}
