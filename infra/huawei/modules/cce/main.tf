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

  # cce.s1.* = single-master (non-HA) cluster flavors.
  # cce.s2.* = HA (3-master, multi-AZ) cluster flavors.
  cluster_flavor_id = var.enable_ha_control_plane ? "cce.s2.small" : "cce.s1.small"
}

# ---------------------------------------------------------------------------
# CCE cluster (Standard tier, VM nodes, private API endpoint).
#
# IAM (verified before implementing): `agency_name` is optional. Huawei
# documents that when it is omitted, the cluster automatically falls back
# to its own system agency (cce_admin_trust / cce_cluster_agency), and that
# CCE's automatically-created CCEServiceAgency/CCEAutoClusterAgency already
# cover the minimum permissions basic cluster functions need (node status,
# cluster events, Services without an external load balancer) with no
# manually-created agency required. This architecture has no ELB, no
# EVS/PVC storage, and no autoscaler yet, so no custom agency is created
# here — do not add one until a specific, verified requirement appears
# (e.g. once the elb module exists and needs broader permissions than the
# system agency grants).
#
# Networking: no `eip` is set, so the API endpoint has no public address —
# it is reachable only from within the VPC (or a peered/VPN/bastion path).
# How operators and Argo CD reach this private endpoint is still an open
# question, tracked separately from this resource's implementation.
# ---------------------------------------------------------------------------

resource "huaweicloud_cce_cluster" "this" {
  name         = "${local.name_prefix}-cce"
  cluster_type = "VirtualMachine"
  flavor_id    = local.cluster_flavor_id

  cluster_version = var.cluster_version

  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id

  container_network_type = "overlay_l2"

  multi_az = var.enable_ha_control_plane

  enterprise_project_id = var.enterprise_project_id
}

# ---------------------------------------------------------------------------
# Node pool — fixed size in this phase. No autoscaling: neither
# `scall_enable`/min/max_node_count nor the separate autoscaler add-on are
# configured here (both are required together for autoscaling to actually
# function; deliberately deferred, per the approved Phase 2B scope).
#
# SWR image pulls: not configured here either. CCE automatically generates
# a `default-secret` (auto-rotated SWR credential) per cluster; that is a
# manifest-layer concern for the later Kubernetes/Argo CD deployment, not
# something this Terraform module provisions.
# ---------------------------------------------------------------------------

resource "huaweicloud_cce_node_pool" "this" {
  cluster_id = huaweicloud_cce_cluster.this.id
  name       = "${local.name_prefix}-node-pool"

  initial_node_count = var.node_count
  flavor_id          = var.node_flavor_id
  availability_zone  = var.availability_zone

  subnet_id       = var.subnet_id
  security_groups = [var.security_group_id]

  os       = var.node_os
  key_pair = var.node_key_pair

  root_volume {
    size       = var.node_root_volume_size
    volumetype = var.node_root_volume_type
  }
}
