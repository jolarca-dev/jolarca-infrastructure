# Staging environment variables.
# Keep the surface minimal: defaults live in modules, overrides land here
# only when staging intentionally deviates from production shape.

# ── GCP ──────────────────────────────────────────────────────────────────

variable "project" {
  description = "GCP project for the marketplace staging scope."
  type        = string
  default     = ""
}

variable "region" {
  description = "Primary region. EU residency is mandatory (GDPR Art. 44, PCI-DSS scope containment)."
  type        = string
  default     = "europe-west1"
}

# ── Proxmox ──────────────────────────────────────────────────────────────

variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint URL (e.g. https://pve.example.com:8006)."
  type        = string
  default     = "https://pve:8006"
}

variable "proxmox_insecure" {
  description = "Allow self-signed TLS certificates for the Proxmox API (staging only)."
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Proxmox node name where VMs/LXCs are created."
  type        = string
  default     = "pve"
}

variable "proxmox_template_vm_id" {
  description = "VMID of the cloud-init template to clone VMs from."
  type        = number
  default     = 9000
}

variable "proxmox_lxc_template" {
  description = "OS template for LXC containers (e.g. 'local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst')."
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
}

variable "proxmox_storage" {
  description = "Default Proxmox storage for VM disks and LXC rootfs."
  type        = string
  default     = "local-lvm"
}

variable "proxmox_public_bridge" {
  description = "Proxmox bridge for public-facing network (edge VM only)."
  type        = string
  default     = "vmbr0"
}

variable "proxmox_wg_bridge" {
  description = "Proxmox bridge for WireGuard mesh network (internal VMs/LXCs)."
  type        = string
  default     = "vmbr1"
}

variable "ssh_public_keys" {
  description = "SSH public keys injected into VMs/LXCs via cloud-init."
  type        = list(string)
  default     = []
}

# ── Environment ──────────────────────────────────────────────────────────

variable "environment" {
  description = "Environment name (guardrail: modules may assert on this)."
  type        = string
  default     = "staging"
}
