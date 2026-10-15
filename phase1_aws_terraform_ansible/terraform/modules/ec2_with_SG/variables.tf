variable "name" {
  description = "Name of the instance (also used to name its security group)."
  type        = string
}

variable "vpc_id" {
  description = "VPC where the security group is created."
  type        = string
}

variable "subnet_id" {
  description = "Subnet where the instance is launched."
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the instance."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
}

variable "key_name" {
  description = "Name of the EC2 key pair used for SSH."
  type        = string
}

variable "root_volume_size" {
  description = "Root disk size in GiB."
  type        = number
  default     = 20
}

variable "associate_public_ip" {
  description = "Give the instance a public IP (needed for internet access because there is no NAT gateway)."
  type        = bool
  default     = true
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH to this instance."
  type        = list(string)
  default     = []
}

variable "ssh_source_security_group_ids" {
  description = "Security groups whose members may SSH to this instance (for example the Ansible control node)."
  type        = list(string)
  default     = []
}

variable "user_data" {
  description = "Optional first-boot script (cloud-init)."
  type        = string
  default     = null
}

variable "tags" {
  description = "Extra tags for the resources."
  type        = map(string)
  default     = {}
}
