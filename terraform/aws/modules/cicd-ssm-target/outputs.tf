output "security_group_id" {
  description = "Security group ID of the SSM target — reference this from the EKS cluster's additional security group rules to allow it in."
  value       = aws_security_group.this.id
}

output "instance_id" {
  description = "Instance ID of the SSM target."
  value       = aws_instance.this.id
}
