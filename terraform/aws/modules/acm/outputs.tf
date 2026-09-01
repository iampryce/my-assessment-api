output "certificate_arn" {
  description = "Validated ACM certificate ARN - pass to ingress-nginx's certificate_arn variable."
  value       = aws_acm_certificate_validation.this.certificate_arn
}
