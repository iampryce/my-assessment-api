output "vpc_id" {
  description = "ID of the production VPC."
  value       = module.network.vpc_id
}

output "cce_subnet_id" {
  description = "ID of the production CCE private subnet."
  value       = module.network.cce_subnet_id
}

output "rds_subnet_id" {
  description = "ID of the production RDS private subnet."
  value       = module.network.rds_subnet_id
}

output "cce_security_group_id" {
  description = "ID of the production CCE security group."
  value       = module.network.cce_security_group_id
}

output "rds_security_group_id" {
  description = "ID of the production RDS security group."
  value       = module.network.rds_security_group_id
}

output "nat_gateway_id" {
  description = "ID of the production NAT gateway."
  value       = module.network.nat_gateway_id
}
