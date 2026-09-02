# Proxmox LXC container module — variables.
# Creates containers on Proxmox VE for lightweight workloads (MinIO, monitoring, backup).

variable "name" {
  description = "Container hostname."
  type        = string
}

variable "ct_id" {
  description = "Proxmox CTID. Must be unique per node."
  type        = number

  validation {
    condition     = var.ct_id >= 100 && var.ct_id <= 999999
    error_message = "CTID must be between 100 and 999999."
  }
}

variable "target_node" {
  description = "Proxmox node name."
  type        = string
  default     = "pve"
}

variable "template_ostemplate" {
  description = "OS template path (e.g. 'local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst')."
  type        = string
}

variable "description" {
  description = "Container description."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Proxmox tags (comma-separated)."
  type        = string
  default     = ""
}

# ── Compute ──────────────────────────────────────────────────────────────

variable "cores" {
  description = "Number of CPU cores."
  type        = number
  default     = 2
}

variable "memory" {
  description = "RAM in megabytes."
  type        = number
  default     = 2048
}

variable "swap" {
  description = "Swap in megabytes."
  type        = number
  default     = 512
}

# ── Disks ────────────────────────────────────────────────────────────────

variable "rootfs_storage" {
  description = "Storage for root filesystem."
  type        = string
  default     = "local-lvm"
}

variable "rootfs_size" {
  description = "Root filesystem size."
  type        = string
  default     = "8G"
}

variable "mount_points" {
  description = "Additional mount points."
  type = list(object({
    key        = string
    storage    = string
    size       = string
    mountpoint = string
  }))
  default = []
}

# ── Network ──────────────────────────────────────────────────────────────

variable "networks" {
  description = "Network interface configurations."
  type = list(object({
    name     = optional(string, "eth0")
    bridge   = string
    ip       = optional(string, "dhcp")
    gateway  = optional(string, null)
    firewall = optional(bool, true)
  }))
  default = [{
    bridge = "vmbr0"
    ip     = "dhcp"
  }]
}

# ── Features ─────────────────────────────────────────────────────────────

variable "unprivileged" {
  description = "Create unprivileged container."
  type        = bool
  default     = true
}

variable "nesting" {
  description = "Enable nesting (required for Docker-in-LXC)."
  type        = bool
  default     = false
}

variable "keyctl" {
  description = "Enable keyctl (required for some systemd services)."
  type        = bool
  default     = true
}

# ── OS ───────────────────────────────────────────────────────────────────

variable "ostype" {
  description = "OS type for the container."
  type        = string
  default     = "debian"
}

# ── Lifecycle ────────────────────────────────────────────────────────────

variable "onboot" {
  description = "Start container on Proxmox node boot."
  type        = bool
  default     = true
}

variable "startup_order" {
  description = "Startup/shutdown order."
  type        = number
  default     = 200
}

variable "protection" {
  description = "Protect against accidental removal."
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environment label."
  type        = string
  default     = "staging"
}
