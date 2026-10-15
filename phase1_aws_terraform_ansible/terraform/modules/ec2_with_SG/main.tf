resource "aws_security_group" "this" {
  name_prefix = "${var.name}-sg-"
  description = "SSH access for ${var.name}"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh_from_cidr" {
  for_each = toset(var.ssh_cidr_blocks)

  security_group_id = aws_security_group.this.id
  description       = "SSH from approved CIDR"
  cidr_ipv4         = each.value
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

# count (not for_each) because these IDs are only known after the other security group exists.
resource "aws_vpc_security_group_ingress_rule" "ssh_from_sg" {
  count = length(var.ssh_source_security_group_ids)

  security_group_id            = aws_security_group.this.id
  description                  = "SSH from approved security group"
  referenced_security_group_id = var.ssh_source_security_group_ids[count.index]
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.this.id
  description       = "Outbound for OS updates and Docker downloads"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  key_name                    = var.key_name
  associate_public_ip_address = var.associate_public_ip
  user_data                   = var.user_data

  # IMDSv2 only: blocks a common credential-theft technique.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    # A newer Ubuntu AMI should not silently replace a running server.
    ignore_changes = [ami]
  }
}
