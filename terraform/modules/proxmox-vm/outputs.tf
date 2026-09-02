# Proxmox VM module — outputs.

output "vm_id" {
  description = "Proxmox VMID of the created VM."
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "name" {
  description = "Hostname of the created VM."
  value       = proxmox_virtual_environment_vm.this.name
}

output "ipv4_addresses" {
  description = "IPv4 addresses assigned to the VM (from guest agent)."
  value       = proxmox_virtual_environment_vm.this.ipv4_addresses
}

output "network_interface_names" {
  description = "Network interface names as seen by the guest OS."
  value       = proxmox_virtual_environment_vm.this.network_interface_names
}

output "node_name" {
  description = "Proxmox node where the VM is running."
  value       = proxmox_virtual_environment_vm.this.node_name
}
