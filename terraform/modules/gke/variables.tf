# modules/gke — variables.

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region. EU residency mandatory."
  type        = string
  default     = "europe-west1"
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "network_id" {
  description = "VPC network self-link (from networking module)."
  type        = string
}

variable "subnet_name" {
  description = "Subnet name for GKE nodes."
  type        = string
}

variable "master_cidr" {
  description = "CIDR block for the GKE master (private endpoint)."
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_cidrs" {
  description = "CIDR blocks authorized to reach the GKE master."
  type = list(object({
    name = string
    cidr = string
  }))
  default = []
}

variable "release_channel" {
  description = "GKE release channel (REGULAR, RAPID, STABLE)."
  type        = string
  default     = "REGULAR"
}

variable "machine_type" {
  description = "Machine type for GKE nodes."
  type        = string
  default     = "e2-standard-4"
}

variable "node_count" {
  description = "Initial node count per zone."
  type        = number
  default     = 1
}

variable "min_node_count" {
  description = "Minimum node count for autoscaling."
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum node count for autoscaling."
  type        = number
  default     = 5
}
