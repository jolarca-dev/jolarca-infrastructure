# Staging environment outputs.
# Outputs are the only sanctioned channel for CI to surface resource facts;
# they must never contain secret material (SOC 2 CC6.6).

# ── Proxmox VMs ─────────────────────────────────────────────────────────

output "edge_vm" {
  description = "Edge VM details."
  value = {
    vm_id = module.edge_vm.vm_id
    name  = module.edge_vm.name
  }
}

output "app_vm" {
  description = "App VM details."
  value = {
    vm_id = module.app_vm.vm_id
    name  = module.app_vm.name
  }
}

output "db_vm" {
  description = "Database VM details."
  value = {
    vm_id = module.db_vm.vm_id
    name  = module.db_vm.name
  }
}

output "vault_vm" {
  description = "Vault VM details."
  value = {
    vm_id = module.vault_vm.vm_id
    name  = module.vault_vm.name
  }
}

# ── Proxmox LXCs ────────────────────────────────────────────────────────

output "minio_lxc" {
  description = "MinIO LXC details."
  value = {
    ct_id = module.minio_lxc.ct_id
    name  = module.minio_lxc.name
  }
}

output "monitor_lxc" {
  description = "Monitor LXC details."
  value = {
    ct_id = module.monitor_lxc.ct_id
    name  = module.monitor_lxc.name
  }
}

output "backup_lxc" {
  description = "Backup LXC details."
  value = {
    ct_id = module.backup_lxc.ct_id
    name  = module.backup_lxc.name
  }
}

# ── GCP ─────────────────────────────────────────────────────────────────

output "gcp_network" {
  description = "GCP VPC network name."
  value       = module.networking.network_name
}

output "gke_cluster" {
  description = "GKE cluster name."
  value       = module.gke.cluster_name
}

output "workload_identity_pool" {
  description = "Workload Identity pool for GKE."
  value       = module.gke.workload_identity_pool
}
