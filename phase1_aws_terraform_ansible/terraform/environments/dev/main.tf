provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Official Canonical Ubuntu image (owner ID is Canonical's).
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = [var.ubuntu_ami_name_pattern]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Asks AWS which public IP you are connecting from.
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Could not detect your public IP. Add it manually in allowed_ssh_cidrs."
    }
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
  ssh_cidrs  = distinct(concat([local.my_ip_cidr], var.allowed_ssh_cidrs))
}

# One key pair shared by both servers. Only the public key is uploaded.
resource "aws_key_pair" "this" {
  key_name   = "${local.name_prefix}-key"
  public_key = file(pathexpand(var.public_key_path))
}

module "network" {
  source = "../../modules/vpc_subnet_igw_rtb"

  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  availability_zone  = data.aws_availability_zones.available.names[0]
}

# Control node ("master"): Ansible is installed here on first boot.
module "control_node" {
  source = "../../modules/ec2_with_SG"

  name             = "${local.name_prefix}-control"
  vpc_id           = module.network.vpc_id
  subnet_id        = module.network.public_subnet_id
  ami_id           = data.aws_ami.ubuntu.id
  instance_type    = var.instance_type
  key_name         = aws_key_pair.this.key_name
  root_volume_size = var.root_volume_size
  ssh_cidr_blocks  = local.ssh_cidrs # was: var.allowed_ssh_cidrs
  user_data        = file("${path.module}/templates/control_node_userdata.sh")
  tags             = merge(local.common_tags, { Role = "control" })
}

# Managed node ("slave"): only reachable over SSH from the control node.
module "managed_node" {
  source = "../../modules/ec2_with_SG"

  name                          = "${local.name_prefix}-managed"
  vpc_id                        = module.network.vpc_id
  subnet_id                     = module.network.public_subnet_id
  ami_id                        = data.aws_ami.ubuntu.id
  instance_type                 = var.instance_type
  key_name                      = aws_key_pair.this.key_name
  root_volume_size              = var.root_volume_size
  ssh_source_security_group_ids = [module.control_node.security_group_id]
  tags                          = merge(local.common_tags, { Role = "managed" })
}

# Writes the Ansible inventory so Terraform's output feeds straight into Ansible.
resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../../../ansible/inventory/hosts.ini"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/inventory.tftpl", {
    managed_private_ip = module.managed_node.private_ip
    ssh_user           = var.ssh_user
  })
}
