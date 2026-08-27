output "vpc_id" {
  description = "ID of the staging validation VPC."
  value       = module.network.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (EKS nodes and RDS)."
  value       = module.network.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs (unused by anything created so far)."
  value       = module.network.public_subnet_ids
}

output "eks_cluster_name" {
  description = "Name of the staging EKS cluster."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint (private-only — not publicly reachable)."
  value       = module.eks.cluster_endpoint
}

output "eks_node_security_group_id" {
  description = "Security group ID shared by EKS worker nodes."
  value       = module.eks.node_security_group_id
}

output "rds_endpoint" {
  description = "RDS PostgreSQL connection endpoint (private only)."
  value       = module.rds.endpoint
}

output "rds_security_group_id" {
  description = "Security group ID for RDS — ingress from EKS nodes on 5432 only."
  value       = module.rds.security_group_id
}
