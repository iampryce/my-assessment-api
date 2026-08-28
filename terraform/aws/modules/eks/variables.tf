variable "environment" {
  description = "Environment name used for resource naming/tagging (e.g. \"staging\", \"production\")."
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be either \"staging\" or \"production\"."
  }
}

variable "vpc_id" {
  description = "VPC ID — pass module.network.vpc_id."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for worker nodes and the control plane ENIs — pass module.network.private_subnet_ids."
  type        = list(string)
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version."
  type        = string
}

variable "node_instance_type" {
  description = "EC2 instance type for the managed node group."
  type        = string
}

variable "node_desired_size" {
  description = "Desired worker node count."
  type        = number
}

variable "node_min_size" {
  description = "Minimum worker node count."
  type        = number
}

variable "node_max_size" {
  description = "Maximum worker node count."
  type        = number
}
