# Proxmox VM module — main configuration.
# Creates a single VM cloned from a cloud-init template.
# Provider: bpg/proxmox (BPG — actively maintained Proxmox provider).
#
# Reference: PROXMOX_DEPLOYMENT_PLAN.md §1.3 for the VM/LXC layout.

resource "proxmox_virtual_environment_vm" "this" {
  name        = var.name
  vm_id       = var.vm_id
  node_name   = var.target_node
  description = var.description
  tags        = compact(split(",", var.tags))

  on_boot    = var.onboot
  protection = var.protection

  startup {
    order      = var.startup_order
    up_delay   = 0
    down_delay = 0
  }

  agent {
    enabled = var.qemu_agent
  }

  # ── Compute ──────────────────────────────────────────────────────────

  cpu {
    cores   = var.cores
    sockets = var.sockets
    type    = "host"
  }

  memory {
    dedicated = var.memory
  }

  # ── Clone from cloud-init template ──────────────────────────────────

  clone {
    vm_id = var.clone_template_id
    full  = true
  }

  # ── Disks ────────────────────────────────────────────────────────────

  dynamic "disk" {
    for_each = var.disks
    content {
      datastore_id = disk.value.storage
      size         = disk.value.size
      interface    = "${disk.value.type}${disk.key}"
      iothread     = disk.value.iothread
      file_format  = "raw"
    }
  }

  # ── Network interfaces ──────────────────────────────────────────────

  dynamic "network_device" {
    for_each = var.networks
    content {
      bridge   = network_device.value.bridge
      model    = network_device.value.model
      firewall = network_device.value.firewall
      vlan_id  = network_device.value.vlan
    }
  }

  # ── Cloud-init ──────────────────────────────────────────────────────

  initialization {
    user_data_file_id = proxmox_virtual_environment_file.cloud_init_config.id
  }

  # ── Boot ─────────────────────────────────────────────────────────────

  boot_order = var.boot_order

  # ── Lifecycle ────────────────────────────────────────────────────────

  lifecycle {
    ignore_changes = [
      # Cloud-init may modify these after first boot; don't fight it.
      initialization[0].user_data_file_id,
    ]
  }
}

# ── Cloud-init configuration ────────────────────────────────────────────

resource "proxmox_virtual_environment_file" "cloud_init_config" {
  content_type = "snippets"
  datastore_id = var.disks[0].storage
  node_name    = var.target_node

  source_raw {
    data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
      user          = var.ci_user
      ssh_keys      = var.ci_ssh_keys
      ip_config     = var.ci_ip_config
      search_domain = var.ci_search_domain
      nameserver    = var.ci_nameserver
      upgrade       = var.ci_upgrade
      hostname      = var.name
    })
    file_name = "cloud-init-${var.name}.yaml"
  }
}
