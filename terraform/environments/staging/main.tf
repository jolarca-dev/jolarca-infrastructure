# Staging environment — non-prod proving ground.
#
# Purpose: validate IaC changes, module upgrades, and provider version bumps
# against a real (non-production) control plane before they reach
# ../production. State is ISOLATED (ADR-0002): this environment must never
# reference the production backend.
#
# Compliance: ISO 27001 A.8.31 (separation of dev/test/production).
#
# This file manages:
#   1. Proxmox VMs/LXCs (90% bare-metal plane) — via proxmox-vm/lxc modules
#   2. GCP resources (10% plane) — via networking/gke modules
#
# Provider/version pins live in versions.tf (single source of truth).
# Backend stays local/disabled until the state-bucket workstream lands;
# flip to GCS via ADR-0003 using backends/staging.backend.hcl.

# ── Proxmox provider ────────────────────────────────────────────────────
# Connects to the Proxmox VE host. Credentials from environment variables:
#   PM_API_TOKEN / PM_API_TOKEN_SECRET (preferred) or
#   PM_USER / PM_PASSWORD

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = var.proxmox_insecure

  # API token authentication (preferred over user/password)
  # Token and secret sourced from environment variables.
}

# ── GCP provider ────────────────────────────────────────────────────────

provider "google" {
  project = var.project
  region  = var.region
}

# ── Proxmox VMs (90% plane) ────────────────────────────────────────────
# VM layout from PROXMOX_DEPLOYMENT_PLAN.md §1.3.
# All VMs are cloned from a cloud-init template (template VMID set in tfvars).

module "edge_vm" {
  source = "../../modules/proxmox-vm"

  name              = "edge-staging"
  vm_id             = 100
  target_node       = var.proxmox_node
  clone_template_id = var.proxmox_template_vm_id
  description       = "nginx reverse proxy, TLS termination"
  tags              = "staging,edge,nginx"

  cores   = 2
  memory  = 2048
  sockets = 1

  disks = [{
    storage  = var.proxmox_storage
    size     = "20G"
    type     = "scsi"
    iothread = false
  }]

  networks = [{
    bridge   = var.proxmox_public_bridge
    firewall = true
  }]

  ci_ssh_keys      = var.ssh_public_keys
  ci_ip_config     = ["ip=10.10.1.1/24,gw=10.10.1.254"]
  ci_nameserver    = "1.1.1.1"
  ci_search_domain = "staging.jolarca.internal"

  environment   = "staging"
  startup_order = 10
}

module "app_vm" {
  source = "../../modules/proxmox-vm"

  name              = "app-staging"
  vm_id             = 101
  target_node       = var.proxmox_node
  clone_template_id = var.proxmox_template_vm_id
  description       = "Django + Next.js + Celery"
  tags              = "staging,app,django"

  cores   = 4
  memory  = 8192
  sockets = 1

  disks = [{
    storage  = var.proxmox_storage
    size     = "40G"
    type     = "scsi"
    iothread = false
  }]

  networks = [{
    bridge   = var.proxmox_wg_bridge
    firewall = true
  }]

  ci_ssh_keys      = var.ssh_public_keys
  ci_ip_config     = ["ip=10.10.1.2/24,gw=10.10.1.254"]
  ci_nameserver    = "1.1.1.1"
  ci_search_domain = "staging.jolarca.internal"

  environment   = "staging"
  startup_order = 20
}

module "db_vm" {
  source = "../../modules/proxmox-vm"

  name              = "db-staging"
  vm_id             = 102
  target_node       = var.proxmox_node
  clone_template_id = var.proxmox_template_vm_id
  description       = "PostgreSQL 17 + PostGIS 3.5"
  tags              = "staging,db,postgresql"

  cores   = 4
  memory  = 8192
  sockets = 1

  disks = [{
    storage  = var.proxmox_storage
    size     = "100G"
    type     = "scsi"
    iothread = true
  }]

  networks = [{
    bridge   = var.proxmox_wg_bridge
    firewall = true
  }]

  ci_ssh_keys      = var.ssh_public_keys
  ci_ip_config     = ["ip=10.10.1.3/24,gw=10.10.1.254"]
  ci_nameserver    = "1.1.1.1"
  ci_search_domain = "staging.jolarca.internal"

  environment   = "staging"
  startup_order = 30
}

module "vault_vm" {
  source = "../../modules/proxmox-vm"

  name              = "vault-staging"
  vm_id             = 103
  target_node       = var.proxmox_node
  clone_template_id = var.proxmox_template_vm_id
  description       = "HashiCorp Vault (raft, TLS)"
  tags              = "staging,vault,secrets"

  cores   = 1
  memory  = 1024
  sockets = 1

  disks = [{
    storage  = var.proxmox_storage
    size     = "10G"
    type     = "scsi"
    iothread = false
  }]

  networks = [{
    bridge   = var.proxmox_wg_bridge
    firewall = true
  }]

  ci_ssh_keys      = var.ssh_public_keys
  ci_ip_config     = ["ip=10.10.1.4/24,gw=10.10.1.254"]
  ci_nameserver    = "1.1.1.1"
  ci_search_domain = "staging.jolarca.internal"

  environment   = "staging"
  startup_order = 15
  protection    = true # Protect Vault VM from accidental removal
}

# ── Proxmox LXCs (lightweight workloads) ────────────────────────────────

module "minio_lxc" {
  source = "../../modules/proxmox-lxc"

  name                = "minio-staging"
  ct_id               = 200
  target_node         = var.proxmox_node
  template_ostemplate = var.proxmox_lxc_template
  description         = "MinIO S3-compatible object storage"
  tags                = "staging,minio,storage"

  cores  = 2
  memory = 4096
  swap   = 1024

  rootfs_storage = var.proxmox_storage
  rootfs_size    = "200G"

  mount_points = [{
    key        = "mp0"
    storage    = var.proxmox_storage
    size       = "200G"
    mountpoint = "/data"
  }]

  networks = [{
    bridge = var.proxmox_wg_bridge
    ip     = "10.10.1.5/24"
  }]

  environment = "staging"
}

module "monitor_lxc" {
  source = "../../modules/proxmox-lxc"

  name                = "monitor-staging"
  ct_id               = 201
  target_node         = var.proxmox_node
  template_ostemplate = var.proxmox_lxc_template
  description         = "Prometheus + Grafana + Alertmanager"
  tags                = "staging,monitor,prometheus"

  cores  = 2
  memory = 4096
  swap   = 1024

  rootfs_storage = var.proxmox_storage
  rootfs_size    = "40G"

  networks = [{
    bridge = var.proxmox_wg_bridge
    ip     = "10.10.1.6/24"
  }]

  environment = "staging"
}

module "backup_lxc" {
  source = "../../modules/proxmox-lxc"

  name                = "backup-staging"
  ct_id               = 202
  target_node         = var.proxmox_node
  template_ostemplate = var.proxmox_lxc_template
  description         = "BorgBackup client + offsite sync"
  tags                = "staging,backup,borg"

  cores  = 1
  memory = 2048
  swap   = 512

  rootfs_storage = var.proxmox_storage
  rootfs_size    = "500G"

  networks = [{
    bridge = var.proxmox_wg_bridge
    ip     = "10.10.1.7/24"
  }]

  environment = "staging"
}

# ── GCP networking (10% plane) ──────────────────────────────────────────

module "networking" {
  source = "../../modules/networking"

  project_id  = var.project
  region      = var.region
  environment = "staging"

  subnets = [{
    name          = "gke"
    ip_cidr_range = "10.20.0.0/24"
    pods_cidr     = "10.20.32.0/20"
    services_cidr = "10.20.48.0/24"
  }]

  wireguard_source_ranges = ["10.10.0.0/16"]
}

# ── GKE cluster (10% plane) ────────────────────────────────────────────

module "gke" {
  source = "../../modules/gke"

  project_id  = var.project
  region      = var.region
  environment = "staging"

  network_id  = module.networking.network_id
  subnet_name = module.networking.subnet_names["gke"]

  master_cidr = "172.16.0.0/28"
  master_authorized_cidrs = [
    {
      name = "wireguard-mesh"
      cidr = "10.10.0.0/16"
    },
  ]

  release_channel = "REGULAR"
  machine_type    = "e2-standard-2"
  node_count      = 1
  min_node_count  = 1
  max_node_count  = 3
}
