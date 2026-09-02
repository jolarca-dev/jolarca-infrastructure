# modules/networking — variables.

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region. EU residency mandatory (GDPR Art. 44)."
  type        = string
  default     = "europe-west1"
}

variable "environment" {
  description = "Environment name (staging/production)."
  type        = string
}

variable "subnets" {
  description = "List of subnet configurations."
  type = list(object({
    name          = string
    ip_cidr_range = string
    pods_cidr     = string
    services_cidr = string
  }))
  default = [{
    name          = "gke"
    ip_cidr_range = "10.20.0.0/24"
    pods_cidr     = "10.20.32.0/20"
    services_cidr = "10.20.48.0/24"
  }]
}

variable "wireguard_source_ranges" {
  description = "CIDR ranges allowed to reach the WireGuard gateway (the bare-metal mesh)."
  type        = list(string)
  default     = ["10.10.0.0/16"]
}
