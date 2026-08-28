terraform {
  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "~> 1.70"
    }
  }
}

locals {
  name_prefix       = "cashonrails-${var.environment}"
  cluster_flavor_id = var.enable_ha_control_plane ? "cce.s2.small" : "cce.s1.small"
}

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
