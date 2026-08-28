output "endpoint" {
  description = "RDS PostgreSQL connection endpoint (private only)."
  value       = module.rds.db_instance_endpoint
}

output "security_group_id" {
  description = "Security group ID for RDS — ingress from EKS nodes on 5432 only."
  value       = aws_security_group.rds.id
}
