# Proxmox VM module — variables.
# Creates one or more VMs on a Proxmox VE host from a cloud-init template.
# Designed for the 90% bare-metal plane (PROXMOX_DEPLOYMENT_PLAN.md).

variable "name" {
  description = "Base hostname for the VM(s). If count > 1, a numeric suffix is appended."
  type        = string
}

variable "vm_id" {
  description = "Proxmox VMID. Must be unique per node. Set explicitly to match the deployment plan."
  type        = number

  validation {
    condition     = var.vm_id >= 100 && var.vm_id <= 999999
    error_message = "VMID must be between 100 and 999999."
  }
}

variable "target_node" {
  description = "Proxmox node name where the VM will be created."
  type        = string
  default     = "pve"
}

variable "clone_template_id" {
  description = "VMID of the cloud-init template to clone from."
  type        = number
}

variable "description" {
  description = "VM description (shown in Proxmox UI)."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Proxmox tags for the VM (comma-separated)."
  type        = string
  default     = ""
}

# ── Compute ──────────────────────────────────────────────────────────────

variable "cores" {
  description = "Number of CPU cores."
  type        = number
  default     = 2

  validation {
    condition     = var.cores >= 1 && var.cores <= 32
    error_message = "Cores must be between 1 and 32."
  }
}

variable "memory" {
  description = "RAM in megabytes."
  type        = number
  default     = 2048

  validation {
    condition     = var.memory >= 512 && var.memory <= 65536
    error_message = "Memory must be between 512 MB and 65536 MB."
  }
}

variable "sockets" {
  description = "Number of CPU sockets."
  type        = number
  default     = 1
}

# ── Disks ────────────────────────────────────────────────────────────────

variable "disks" {
  description = "List of disk configurations."
  type = list(object({
    storage = string
    size    = string # e.g. "20G", "100G"
    type    = string # "scsi", "virtio", "sata"
    iothread = optional(bool, false)
  }))
  default = [{
    storage  = "local-lvm"
    size     = "20G"
    type     = "scsi"
    iothread = false
  }]
}

# ── Network ──────────────────────────────────────────────────────────────

variable "networks" {
  description = "List of network interface configurations."
  type = list(object({
    model    = optional(string, "virtio")
    bridge   = string
    vlan     = optional(number, null)
    firewall = optional(bool, true)
  }))
  default = [{
    bridge   = "vmbr0"
    firewall = true
  }]
}

# ── Cloud-init ───────────────────────────────────────────────────────────

variable "ci_user" {
  description = "Cloud-init default user."
  type        = string
  default     = "deploy"
}

variable "ci_ssh_keys" {
  description = "SSH public keys to inject via cloud-init."
  type        = list(string)
  default     = []
}

variable "ci_ip_config" {
  description = "Cloud-init IP configuration per interface (e.g. 'ip=dhcp' or 'ip=10.10.1.1/24,gw=10.10.1.254')."
  type        = list(string)
  default     = ["ip=dhcp"]
}

variable "ci_search_domain" {
  description = "Cloud-init search domain."
  type        = string
  default     = ""
}

variable "ci_nameserver" {
  description = "Cloud-init nameserver."
  type        = string
  default     = ""
}

variable "ci_upgrade" {
  description = "Whether to run apt upgrade on first boot."
  type        = bool
  default     = false
}

# ── Operating system ─────────────────────────────────────────────────────

variable "qemu_agent" {
  description = "Enable QEMU guest agent."
  type        = bool
  default     = true
}

variable "boot_order" {
  description = "Boot device order."
  type        = list(string)
  default     = ["scsi0", "ide2", "net0"]
}

# ── Lifecycle ────────────────────────────────────────────────────────────

variable "onboot" {
  description = "Start VM on Proxmox node boot."
  type        = bool
  default     = true
}

variable "startup_order" {
  description = "Startup/shutdown order (lower = earlier start, later shutdown)."
  type        = number
  default     = 100
}

variable "protection" {
  description = "Enable VM protection against accidental removal."
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environment label (staging/production) for tagging."
  type        = string
  default     = "staging"
}
