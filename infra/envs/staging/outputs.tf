output "vpc_id" {
  description = "ID of the staging VPC."
  value       = module.network.vpc_id
}

output "cce_subnet_id" {
  description = "ID of the staging CCE private subnet."
  value       = module.network.cce_subnet_id
}

output "rds_subnet_id" {
  description = "ID of the staging RDS private subnet."
  value       = module.network.rds_subnet_id
}

output "cce_security_group_id" {
  description = "ID of the staging CCE security group."
  value       = module.network.cce_security_group_id
}

output "rds_security_group_id" {
  description = "ID of the staging RDS security group."
  value       = module.network.rds_security_group_id
}

output "nat_gateway_id" {
  description = "ID of the staging NAT gateway."
  value       = module.network.nat_gateway_id
}
