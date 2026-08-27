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

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------

resource "huaweicloud_vpc" "this" {
  name = "${local.name_prefix}-vpc"
  cidr = var.vpc_cidr

  enterprise_project_id = var.enterprise_project_id
}

# ---------------------------------------------------------------------------
# Subnets — CCE and RDS are kept on separate private subnets within the
# same VPC, per the approved network design.
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# RDS route table — makes the "RDS has no internet route" guarantee explicit
# in Terraform, rather than relying on Huawei's default-route-table behaviour.
#
# Every VPC subnet is associated with exactly one route table. New subnets
# are associated with the VPC's default route table unless told otherwise.
# Huawei's public NAT gateway automatically adds a 0.0.0.0/0 route to that
# *default* route table when an SNAT rule is created for the CCE subnet
# (see huaweicloud_nat_snat_rule.cce below) — meaning any other subnet left
# on the default route table would inherit that same route.
#
# This custom route table is associated only with the rds subnet and
# deliberately defines no `route` blocks: it carries only the automatic
# intra-VPC "local" route every route table has, and no route to the NAT
# gateway or the internet. Associating the rds subnet here moves it off the
# default route table entirely, so the NAT gateway's automatic route can
# never apply to it, regardless of what the CCE subnet's SNAT rule adds.
#
# The CCE subnet is deliberately left on the VPC's default route table so
# its outbound NAT path (see the NAT section below) stays intact.
# ---------------------------------------------------------------------------

resource "huaweicloud_vpc_route_table" "rds" {
  vpc_id      = huaweicloud_vpc.this.id
  name        = "${local.name_prefix}-rds-rt"
  description = "No route to the NAT gateway or internet. Do not add a 0.0.0.0/0 route here — this is what guarantees RDS has no outbound internet path."

  subnets = [huaweicloud_vpc_subnet.rds.id]
}

# ---------------------------------------------------------------------------
# Security groups
#
# CCE -> RDS:5432 is fully defined below.
#
# ELB -> CCE ingress is intentionally NOT defined in this module. The ELB
# and its security group are out of scope for this phase (see approved
# Phase 2a plan); that ingress rule will be added alongside the elb/cce
# modules so this module never references a security group that doesn't
# exist yet.
#
# RDS has no public ingress rule, and none should be added here — its only
# permitted inbound source is the CCE security group.
# ---------------------------------------------------------------------------

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

# Egress decision (finding #2): this security group intentionally defines
# no egress rule, so the RDS instance has no outbound path of its own.
# This is a deliberate choice, not an oversight:
#
#   - The application has no requirement for the RDS instance itself to
#     originate outbound connections — no cross-region replica, external
#     export, or webhook exists in this architecture.
#   - Huawei's own RDS-for-PostgreSQL connectivity documentation only ever
#     describes required INBOUND security group rules for client access
#     (ECS/CCE -> RDS); no Huawei documentation found states that an RDS
#     instance needs an egress rule of its own to function.
#   - Security groups are stateful: replies to the CCE-initiated inbound
#     connection on 5432 are permitted automatically and do not require an
#     egress rule.
#
# UNVERIFIED without a live account: whether Huawei's own RDS management
# plane (automated backups, patching, health checks) routes through this
# customer-defined security group at all, or bypasses it entirely via a
# separate management interface (as most managed-RDS-equivalents do). If a
# live deployment shows RDS provisioning or operation failing because of
# this restrictive posture, that is the first thing to revisit — add a
# narrowly scoped egress rule then, with the specific requirement that
# forced it, rather than reverting to unrestricted egress.

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

# ---------------------------------------------------------------------------
# CCE node-to-node ingress rules (Phase 2B) — required for basic cluster
# networking under the overlay_l2 (tunnel network) container network model.
#
# Verified against Huawei's own documented security-group rule table for
# tunnel-network worker nodes before writing these
# (https://support.huaweicloud.com/intl/en-us/cce_faq/cce_faq_00265.html):
#
#   UDP/4789        0.0.0.0/0        container-to-container VXLAN traffic
#   TCP/10250       master node CIDR kubelet access from the control plane
#   TCP+UDP/30000-32767  0.0.0.0/0   NodePort Services
#   TCP/22          0.0.0.0/0        SSH (Huawei's own guidance recommends
#                                    restricting this)
#
# SSH (port 22) is deliberately NOT opened here: this architecture manages
# nodes via kubectl/Argo CD, not direct SSH, and Huawei's own documentation
# recommends restricting that rule rather than leaving it open by default.
#
# None of these rules expose anything to the public internet in practice —
# CCE worker nodes in this design never receive a public IP (see the NAT
# section above), so "0.0.0.0/0" here only matters for traffic that already
# reached a private interface via the VPC/NAT path.
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# NAT — controlled outbound-only connectivity for CCE nodes. RDS does not
# route through NAT: it is a managed service and does not require outbound
# internet access.
# ---------------------------------------------------------------------------

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
