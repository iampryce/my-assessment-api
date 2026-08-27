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

output "cce_cluster_id" {
  description = "ID of the staging CCE cluster."
  value       = module.cce.cluster_id
}

output "cce_node_pool_id" {
  description = "ID of the staging CCE node pool."
  value       = module.cce.node_pool_id
}

output "rds_instance_id" {
  description = "ID of the staging RDS instance."
  value       = module.rds.instance_id
}

output "rds_private_ips" {
  description = "Private IP address(es) of the staging RDS instance."
  value       = module.rds.private_ips
}
