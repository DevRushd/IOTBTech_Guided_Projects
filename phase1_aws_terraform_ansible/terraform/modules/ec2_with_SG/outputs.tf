output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP address."
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IP address (empty if none assigned)."
  value       = aws_instance.this.public_ip
}

output "security_group_id" {
  description = "ID of the instance's security group."
  value       = aws_security_group.this.id
}
