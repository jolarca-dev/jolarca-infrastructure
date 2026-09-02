# Proxmox LXC module — outputs.

output "ct_id" {
  description = "Proxmox CTID of the created container."
  value       = proxmox_virtual_environment_container.this.vm_id
}

output "name" {
  description = "Hostname of the created container."
  value       = var.name
}

output "node_name" {
  description = "Proxmox node where the container is running."
  value       = proxmox_virtual_environment_container.this.node_name
}
