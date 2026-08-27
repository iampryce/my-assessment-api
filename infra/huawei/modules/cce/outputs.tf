output "cluster_id" {
  description = "ID of the CCE cluster."
  value       = huaweicloud_cce_cluster.this.id
}

output "cluster_name" {
  description = "Name of the CCE cluster."
  value       = huaweicloud_cce_cluster.this.name
}

output "node_pool_id" {
  description = "ID of the CCE node pool."
  value       = huaweicloud_cce_node_pool.this.id
}
