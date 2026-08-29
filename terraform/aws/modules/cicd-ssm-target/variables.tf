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

variable "subnet_id" {
  description = "A single private subnet ID to place the SSM target in — pass module.network.private_subnet_ids[0]."
  type        = string
}

variable "ami_id" {
  description = "Amazon Linux 2023 x86_64 AMI ID. Look up the current one with: aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 --query Parameter.Value --output text --region us-east-1"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the SSM target — smallest practical size, this instance runs no workload."
  type        = string
  default     = "t3.micro"
}
