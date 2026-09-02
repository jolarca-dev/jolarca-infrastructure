# Terraform Proxmox Modules — Day 1 Guide

This document explains how to use the Terraform modules to provision
Proxmox VMs and LXCs on Day 1 when hardware arrives.

## Architecture

```
terraform/
├── modules/
│   ├── proxmox-vm/          # VM provisioning from cloud-init template
│   ├── proxmox-lxc/         # LXC container provisioning
│   ├── networking/          # GCP VPC (10% plane)
│   ├── gke/                 # GKE cluster (10% plane)
│   ├── state-bucket/        # GCS state backend (ADR-0003)
│   └── github-org/          # GitHub org governance (live)
├── environments/
│   ├── staging/             # Staging — Proxmox + GCP (validated first)
│   └── production/          # Production — GitHub live, Proxmox/GCP after staging soak
└── backends/
    ├── staging.backend.hcl  # GCS backend config
    └── production.backend.hcl
```

## Prerequisites

### 1. Proxmox VE host

- Proxmox VE 8.x installed and hardened
- API token created for Terraform (read/write)
- Cloud-init template prepared (see below)
- Network bridges configured:
  - `vmbr0` — public-facing (edge VM only)
  - `vmbr1` — WireGuard mesh (internal VMs/LXCs)

### 2. Cloud-init template

Create a Debian 12 cloud-init template on Proxmox:

```bash
# On Proxmox host
# 1. Download Debian 12 cloud image
wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2

# 2. Create a template VM (VMID 9000)
qm create 9000 --name "debian-12-cloud-init-template" --memory 2048 --cores 2
qm importdisk 9000 debian-12-generic-amd64.qcow2 local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1
qm set 9000 --ciuser deploy
qm template 9000
```

### 3. Terraform installed

```bash
# Install Terraform >= 1.6.0
# https://developer.hashicorp.com/terraform/downloads
```

### 4. Proxmox API credentials

Set environment variables (never commit these):

```bash
export PM_API_TOKEN="user@pam!token-name=token-value"
# Or for user/password:
export PM_USER="root@pam"
export PM_PASSWORD="your-password"
```

## Day 1 Procedure

### Step 1: Fill in staging variables

Edit `terraform/environments/staging/terraform.tfvars`:

```hcl
environment = "staging"
region      = "europe-west1"

# GCP (fill when project exists)
# project = "jolm-staging-XXXXXX"

# Proxmox (fill when hardware arrives)
proxmox_endpoint         = "https://pve.your-domain.com:8006"
proxmox_node             = "pve"
proxmox_template_vm_id   = 9000
proxmox_lxc_template     = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
proxmox_storage          = "local-lvm"
proxmox_public_bridge    = "vmbr0"
proxmox_wg_bridge        = "vmbr1"

ssh_public_keys = [
  "ssh-ed25519 AAAA... operator@your-domain.com",
]
```

### Step 2: Initialize Terraform

```bash
cd terraform/environments/staging

terraform init
```

### Step 3: Plan

```bash
terraform plan -out=tfplan

# Review the plan carefully:
# - 4 VMs (edge, app, db, vault)
# - 3 LXCs (minio, monitor, backup)
# - GCP VPC + GKE cluster (if GCP project is configured)
```

### Step 4: Apply

```bash
terraform apply tfplan
```

### Step 5: Verify

```bash
# Check outputs
terraform output

# Verify VMs on Proxmox
# - VM 100: edge-staging (2 CPU, 2G RAM, 20G disk)
# - VM 101: app-staging (4 CPU, 8G RAM, 40G disk)
# - VM 102: db-staging (4 CPU, 8G RAM, 100G disk)
# - VM 103: vault-staging (1 CPU, 1G RAM, 10G disk)
# - CT 200: minio-staging (2 CPU, 4G RAM, 200G disk)
# - CT 201: monitor-staging (2 CPU, 4G RAM, 40G disk)
# - CT 202: backup-staging (1 CPU, 2G RAM, 500G disk)

# SSH into a VM
ssh deploy@10.10.1.1  # edge-staging via WireGuard
```

### Step 6: Run Ansible playbooks

After VMs are provisioned, run the Ansible playbooks:

```bash
cd ../../ansible

# 1. Harden all hosts
ansible-playbook playbooks/00-hardening.yml

# 2. Configure WireGuard mesh
ansible-playbook playbooks/10-wireguard.yml

# 3. Install PostgreSQL
ansible-playbook playbooks/20-postgresql.yml

# 4. Install Vault
ansible-playbook playbooks/30-vault.yml

# 5. Install MinIO
ansible-playbook playbooks/40-minio.yml

# 6. Configure nginx
ansible-playbook playbooks/50-nginx.yml

# 7. Configure backup
ansible-playbook playbooks/60-backup.yml
```

## VM/LXC Layout

| ID | Type | Hostname | Role | CPU | RAM | Disk | WG IP |
|----|------|----------|------|-----|-----|------|-------|
| 100 | VM | edge-staging | nginx reverse proxy | 2 | 2G | 20G | 10.10.1.1 |
| 101 | VM | app-staging | Django + Next.js | 4 | 8G | 40G | 10.10.1.2 |
| 102 | VM | db-staging | PostgreSQL 17 | 4 | 8G | 100G | 10.10.1.3 |
| 103 | VM | vault-staging | HashiCorp Vault | 1 | 1G | 10G | 10.10.1.4 |
| 200 | LXC | minio-staging | MinIO storage | 2 | 4G | 200G | 10.10.1.5 |
| 201 | LXC | monitor-staging | Prometheus + Grafana | 2 | 4G | 40G | 10.10.1.6 |
| 202 | LXC | backup-staging | BorgBackup | 1 | 2G | 500G | 10.10.1.7 |

## Module Reference

### proxmox-vm

Creates a VM from a cloud-init template.

```hcl
module "my_vm" {
  source = "../../modules/proxmox-vm"

  name              = "my-vm"
  vm_id             = 150
  target_node       = "pve"
  clone_template_id = 9000

  cores  = 4
  memory = 8192

  disks = [{
    storage = "local-lvm"
    size    = "40G"
    type    = "scsi"
  }]

  networks = [{
    bridge   = "vmbr1"
    firewall = true
  }]

  ci_ssh_keys  = ["ssh-ed25519 AAAA..."]
  ci_ip_config = ["ip=10.10.1.50/24,gw=10.10.1.254"]
}
```

### proxmox-lxc

Creates an LXC container from an OS template.

```hcl
module "my_lxc" {
  source = "../../modules/proxmox-lxc"

  name                = "my-lxc"
  ct_id               = 250
  target_node         = "pve"
  template_ostemplate = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"

  cores  = 2
  memory = 4096

  rootfs_storage = "local-lvm"
  rootfs_size    = "20G"

  networks = [{
    bridge = "vmbr1"
    ip     = "10.10.1.60/24"
  }]
}
```

## Troubleshooting

### Provider authentication fails

```bash
# Verify API token
curl -k https://pve:8006/api2/json/version \
  -H "Authorization: PVEAPIToken=user@pam!token=value"
```

### Template not found

```bash
# List templates on Proxmox
qm list | grep template
```

### Terraform state issues

```bash
# Refresh state from actual infrastructure
terraform refresh

# Import an existing VM
terraform import 'module.edge_vm.proxmox_virtual_environment_vm.this' pve/qemu/100
```

## Production Cutover

After staging validation:

1. Uncomment Proxmox/GCP resources in `environments/production/main.tf`
2. Fill production `terraform.tfvars` with production-appropriate values
3. Use VMIDs starting at 1000 for production (separation from staging)
4. Run `terraform plan` and review
5. Apply with production credentials
