terraform {
  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "~> 1.70"
    }
  }
}

locals {
  name_prefix = "cashonrails-${var.environment}"
}

resource "huaweicloud_vpc" "this" {
  name = "${local.name_prefix}-vpc"
  cidr = var.vpc_cidr

  enterprise_project_id = var.enterprise_project_id
}

resource "huaweicloud_vpc_subnet" "cce" {
  vpc_id = huaweicloud_vpc.this.id

  name              = "${local.name_prefix}-cce-subnet"
  cidr              = var.cce_subnet_cidr
  gateway_ip        = cidrhost(var.cce_subnet_cidr, 1)
  availability_zone = var.availability_zone
}

resource "huaweicloud_vpc_subnet" "rds" {
  vpc_id = huaweicloud_vpc.this.id

  name              = "${local.name_prefix}-rds-subnet"
  cidr              = var.rds_subnet_cidr
  gateway_ip        = cidrhost(var.rds_subnet_cidr, 1)
  availability_zone = var.availability_zone
}

resource "huaweicloud_vpc_route_table" "rds" {
  vpc_id      = huaweicloud_vpc.this.id
  name        = "${local.name_prefix}-rds-rt"
  description = "No route to the NAT gateway or internet. Do not add a 0.0.0.0/0 route here — this is what guarantees RDS has no outbound internet path."

  subnets = [huaweicloud_vpc_subnet.rds.id]
}

resource "huaweicloud_networking_secgroup" "cce" {
  name                  = "${local.name_prefix}-cce-sg"
  description           = "CCE node security group. Ingress from the ELB is added when the elb module is implemented."
  delete_default_rules  = true
  enterprise_project_id = var.enterprise_project_id
}

resource "huaweicloud_networking_secgroup" "rds" {
  name                  = "${local.name_prefix}-rds-sg"
  description           = "RDS security group. Ingress restricted to the CCE security group on 5432 only; no public access."
  delete_default_rules  = true
  enterprise_project_id = var.enterprise_project_id
}

resource "huaweicloud_networking_secgroup_rule" "rds_ingress_from_cce" {
  security_group_id = huaweicloud_networking_secgroup.rds.id

  direction       = "ingress"
  ethertype       = "IPv4"
  protocol        = "tcp"
  port_range_min  = 5432
  port_range_max  = 5432
  remote_group_id = huaweicloud_networking_secgroup.cce.id
  description     = "Allow PostgreSQL access from CCE nodes only"
}

resource "huaweicloud_networking_secgroup_rule" "cce_egress_all" {
  security_group_id = huaweicloud_networking_secgroup.cce.id

  direction        = "egress"
  ethertype        = "IPv4"
  remote_ip_prefix = "0.0.0.0/0"
  description      = "Allow outbound traffic from CCE nodes (image pulls, package updates) via NAT"
}

resource "huaweicloud_networking_secgroup_rule" "cce_vxlan_ingress" {
  security_group_id = huaweicloud_networking_secgroup.cce.id

  direction        = "ingress"
  ethertype        = "IPv4"
  protocol         = "udp"
  port_range_min   = 4789
  port_range_max   = 4789
  remote_ip_prefix = "0.0.0.0/0"
  description      = "Container-to-container VXLAN traffic (overlay_l2 tunnel network)"
}

resource "huaweicloud_networking_secgroup_rule" "cce_kubelet_ingress" {
  security_group_id = huaweicloud_networking_secgroup.cce.id

  direction        = "ingress"
  ethertype        = "IPv4"
  protocol         = "tcp"
  port_range_min   = 10250
  port_range_max   = 10250
  remote_ip_prefix = var.vpc_cidr
  description      = "Allow the CCE control plane to reach kubelet on worker nodes. Scoped to the VPC CIDR as a proxy for the master nodes' actual network location — confirm the real master-node CIDR against a live cluster and narrow this if it differs."
}

resource "huaweicloud_networking_secgroup_rule" "cce_nodeport_ingress_tcp" {
  security_group_id = huaweicloud_networking_secgroup.cce.id

  direction        = "ingress"
  ethertype        = "IPv4"
  protocol         = "tcp"
  port_range_min   = 30000
  port_range_max   = 32767
  remote_ip_prefix = "0.0.0.0/0"
  description      = "NodePort Service range (tunnel network model)"
}

resource "huaweicloud_networking_secgroup_rule" "cce_nodeport_ingress_udp" {
  security_group_id = huaweicloud_networking_secgroup.cce.id

  direction        = "ingress"
  ethertype        = "IPv4"
  protocol         = "udp"
  port_range_min   = 30000
  port_range_max   = 32767
  remote_ip_prefix = "0.0.0.0/0"
  description      = "NodePort Service range (tunnel network model)"
}

resource "huaweicloud_vpc_eip" "nat" {
  publicip {
    type = "5_bgp"
  }

  bandwidth {
    name        = "${local.name_prefix}-nat-bandwidth"
    size        = 5
    share_type  = "PER"
    charge_mode = "traffic"
  }

  enterprise_project_id = var.enterprise_project_id
}

resource "huaweicloud_nat_gateway" "this" {
  name      = "${local.name_prefix}-nat"
  spec      = var.nat_gateway_spec
  vpc_id    = huaweicloud_vpc.this.id
  subnet_id = huaweicloud_vpc_subnet.cce.id

  enterprise_project_id = var.enterprise_project_id
}

resource "huaweicloud_nat_snat_rule" "cce" {
  nat_gateway_id = huaweicloud_nat_gateway.this.id
  subnet_id      = huaweicloud_vpc_subnet.cce.id
  floating_ip_id = huaweicloud_vpc_eip.nat.id
}
