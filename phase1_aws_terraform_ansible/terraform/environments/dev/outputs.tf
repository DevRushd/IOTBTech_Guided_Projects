output "control_node_public_ip" {
  description = "Public IP of the control node (SSH here from your laptop)."
  value       = module.control_node.public_ip
}

output "control_node_private_ip" {
  description = "Private IP of the control node."
  value       = module.control_node.private_ip
}

output "managed_node_private_ip" {
  description = "Private IP of the managed node (Ansible connects to this address)."
  value       = module.managed_node.private_ip
}

output "instance_ids" {
  description = "Instance IDs, handy for the AWS console and CLI."
  value = {
    control = module.control_node.instance_id
    managed = module.managed_node.instance_id
  }
}

output "copy_ansible_command" {
  description = "Run from terraform/environments/dev after ssh-add: copies the Ansible folder to the control node."
  value       = "scp -r ../../../ansible ${var.ssh_user}@${module.control_node.public_ip}:~/"
}

output "ssh_command_control" {
  description = "Log in to the control node with SSH agent forwarding (-A) so it can reach the managed node."
  value       = "ssh -A ${var.ssh_user}@${module.control_node.public_ip}"
}
