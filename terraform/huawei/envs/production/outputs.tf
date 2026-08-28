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

output "cce_cluster_id" {
  description = "ID of the production CCE cluster."
  value       = module.cce.cluster_id
}

output "cce_node_pool_id" {
  description = "ID of the production CCE node pool."
  value       = module.cce.node_pool_id
}

output "rds_instance_id" {
  description = "ID of the production RDS instance."
  value       = module.rds.instance_id
}

output "rds_private_ips" {
  description = "Private IP address(es) of the production RDS instance."
  value       = module.rds.private_ips
}
