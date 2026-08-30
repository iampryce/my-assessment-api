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

variable "cicd_ssm_target_security_group_id" {
  description = "Security group ID of the CI/CD SSM deployment bridge — pass module.cicd_ssm_target.security_group_id. Allowed 443 ingress to the cluster so the deploy pipeline can reach the private API."
  type        = string
}

variable "admin_principal_arns" {
  description = "IAM user/role ARNs to grant standing cluster-wide edit access, e.g. for personal admin use. Empty by default - not tied to any specific identity, so this stays reusable. Apply via local terraform.tfvars, not CI."
  type        = list(string)
  default     = []
}
