output "instance_id" {
  description = "ID of the RDS instance."
  value       = huaweicloud_rds_instance.this.id
}

output "private_ips" {
  description = "Private IP address(es) of the RDS instance. Empty until the instance actually exists (requires a live account/apply)."
  value       = huaweicloud_rds_instance.this.private_ips
}
