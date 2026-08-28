output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint (private-only — not publicly reachable)."
  value       = module.eks.cluster_endpoint
}

output "node_security_group_id" {
  description = "Security group ID shared by EKS worker nodes."
  value       = module.eks.node_security_group_id
}
