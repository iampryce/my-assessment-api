output "fqdn" {
  description = "The fully-qualified hostname created."
  value       = aws_route53_record.this.fqdn
}
