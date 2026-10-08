output "server_public_ips" {
  description = "Public IP addresses of the Ubuntu servers"
  value       = aws_instance.ubuntu[*].public_ip
}

output "server_private_ips" {
  description = "Private IP addresses of the Ubuntu servers"
  value       = aws_instance.ubuntu[*].private_ip
}

output "ssh_server_1" {
  description = "SSH command for server 1"
  value       = "ssh -i ~/.ssh/id_ed25519 ubuntu@${aws_instance.ubuntu[0].public_ip}"
}

output "ssh_server_2" {
  description = "SSH command for server 2"
  value       = "ssh -i ~/.ssh/id_ed25519 ubuntu@${aws_instance.ubuntu[1].public_ip}"
}