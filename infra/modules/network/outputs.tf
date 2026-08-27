output "vpc_id" {
  description = "ID of the environment VPC."
  value       = huaweicloud_vpc.this.id
}

output "cce_subnet_id" {
  description = "ID of the private subnet used by CCE nodes."
  value       = huaweicloud_vpc_subnet.cce.id
}

output "rds_subnet_id" {
  description = "ID of the private subnet used by RDS."
  value       = huaweicloud_vpc_subnet.rds.id
}

output "cce_security_group_id" {
  description = "ID of the CCE node security group. Does not yet include an ingress rule from an ELB — that is added when the elb module is implemented."
  value       = huaweicloud_networking_secgroup.cce.id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group. Allows ingress from the CCE security group on 5432 only; no public ingress exists."
  value       = huaweicloud_networking_secgroup.rds.id
}

output "nat_gateway_id" {
  description = "ID of the NAT gateway providing outbound-only connectivity for CCE nodes."
  value       = huaweicloud_nat_gateway.this.id
}
