# Production environment variables.
# Production mirrors staging shape but with separate custody (ADR-0002).

# ── GCP ──────────────────────────────────────────────────────────────────

variable "project" {
  description = "GCP project for the marketplace production scope."
  type        = string
  default     = ""
}

variable "region" {
  description = "Primary region. EU residency mandatory."
  type        = string
  default     = "europe-west1"
}

# ── Proxmox ──────────────────────────────────────────────────────────────

variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint URL."
  type        = string
  default     = "https://pve:8006"
}

variable "proxmox_insecure" {
  description = "Allow self-signed TLS certificates (should be false in production)."
  type        = bool
  default     = false
}

variable "proxmox_node" {
  description = "Proxmox node name."
  type        = string
  default     = "pve"
}

variable "proxmox_template_vm_id" {
  description = "VMID of the cloud-init template."
  type        = number
  default     = 9000
}

variable "proxmox_lxc_template" {
  description = "OS template for LXC containers."
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
}

variable "proxmox_storage" {
  description = "Default Proxmox storage."
  type        = string
  default     = "local-lvm"
}

variable "proxmox_public_bridge" {
  description = "Public-facing bridge."
  type        = string
  default     = "vmbr0"
}

variable "proxmox_wg_bridge" {
  description = "WireGuard mesh bridge."
  type        = string
  default     = "vmbr1"
}

variable "ssh_public_keys" {
  description = "SSH public keys for production VMs/LXCs."
  type        = list(string)
  default     = []
}

# ── GitHub (existing) ───────────────────────────────────────────────────

variable "org" {
  description = "GitHub organization."
  type        = string
  # CORRECTED 2026-09-25 (D-06). The marketplace fleet moved to jolarca-dev on
  # 2026-09-02; this default still pointed at journeyoflife-org, so the
  # provider owner — and therefore every plan — targeted the wrong org.
  default = "jolarca-dev"
}

variable "enable_branch_protection" {
  description = "Branch protection toggle."
  type        = bool
  default     = true
}

# ── Environment ──────────────────────────────────────────────────────────

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "production"
}
