# Proxmox LXC container module — main configuration.
# Creates a container from an OS template.
# Provider: bpg/proxmox.
#
# Note: IP addresses for LXC containers are typically configured via DHCP
# or manually after creation. The network_interface block only configures
# the bridge attachment. Use Ansible or cloud-init for IP configuration.

resource "proxmox_virtual_environment_container" "this" {
  vm_id       = var.ct_id
  node_name   = var.target_node
  description = var.description
  tags        = compact(split(",", var.tags))

  start_on_boot = var.onboot

  startup {
    order = var.startup_order
  }

  operating_system {
    template_file_id = var.template_ostemplate
    type             = var.ostype
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory
    swap      = var.swap
  }

  disk {
    datastore_id = var.rootfs_storage
    size         = var.rootfs_size
  }

  dynamic "mount_point" {
    for_each = var.mount_points
    content {
      volume = "${mount_point.value.storage}:${mount_point.value.size}"
      path   = mount_point.value.mountpoint
    }
  }

  dynamic "network_interface" {
    for_each = var.networks
    content {
      name     = network_interface.value.name
      bridge   = network_interface.value.bridge
      firewall = network_interface.value.firewall
    }
  }

  initialization {
    dns {
      servers = ["1.1.1.1", "9.9.9.9"]
    }
  }

  features {
    nesting = var.nesting
    keyctl  = var.keyctl
  }

  unprivileged = var.unprivileged
  protection   = var.protection
}
