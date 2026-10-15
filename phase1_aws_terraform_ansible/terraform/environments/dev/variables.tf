variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short project name used in resource names and tags."
  type        = string
  default     = "iotbtech-phase1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type for both servers."
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Root disk size in GiB for both servers."
  type        = number
  default     = 20
}

variable "ubuntu_ami_name_pattern" {
  description = "Name pattern used to find the Canonical Ubuntu AMI."
  type        = string
  default     = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
}

variable "ssh_user" {
  description = "Default login user of the AMI (ubuntu for Ubuntu images)."
  type        = string
  default     = "ubuntu"
}

variable "public_key_path" {
  description = "Path to the PUBLIC half of your SSH key pair (the .pub file). The private key never goes to Terraform."
  type        = string
  default     = "~/.ssh/iotbtech-aws.pub"
}

variable "allowed_ssh_cidrs" {
  description = "Extra CIDRs allowed to SSH to the control node. Your current public IP is added automatically."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.allowed_ssh_cidrs : can(cidrhost(c, 0))])
    error_message = "Each entry must be a valid CIDR, for example 203.0.113.10/32."
  }

  validation {
    condition     = !contains(var.allowed_ssh_cidrs, "0.0.0.0/0")
    error_message = "Do not open SSH to the whole internet (0.0.0.0/0)."
  }
}
