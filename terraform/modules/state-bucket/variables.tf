# state-bucket module inputs.
# Custody doctrine: ADR-0002 (state isolation), ADR-0003 (remote state),
# security/key-custody.md. No secret values ever enter these variables —
# project IDs and bucket names are identifiers, not credentials.

variable "environment" {
  description = "Environment this state bucket serves. One bucket per environment; never shared (ADR-0002)."
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be 'staging' or 'production' — state isolation is non-negotiable (ADR-0002)."
  }
}

variable "project_id" {
  description = "GCP project hosting the bucket and CMEK key. Operator-supplied (TF_VAR_project_id); never hardcoded in committed tfvars."
  type        = string
}

variable "region" {
  description = "GCP region for bucket and KMS keyring (must match for CMEK)."
  type        = string
  default     = "europe-west1"
}

variable "bucket_name" {
  description = "Globally unique bucket name. MUST contain 'tfstate' — require-cmek.rego keys the CMEK mandate on that convention."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be a valid GCS name (lowercase letters, digits, hyphens; 3-63 chars)."
  }

  validation {
    condition     = can(regex("tfstate", var.bucket_name))
    error_message = "bucket_name must contain 'tfstate' (require-cmek.rego convention) or the CMEK policy gate will not cover it."
  }
}

variable "retention_days" {
  description = "Object retention period in days. 0 disables the retention policy (versioning remains the undo lever)."
  type        = number
  default     = 0

  validation {
    condition     = var.retention_days >= 0 && var.retention_days <= 3650
    error_message = "retention_days must be between 0 and 3650."
  }
}

variable "lock_retention" {
  description = "Lock the retention policy permanently (IRREVERSIBLE). Production doctrine: true once the bucket is verified."
  type        = bool
  default     = false
}

variable "ci_principal" {
  description = <<-EOT
    Workload Identity Federation principal (principal:// or principalSet://)
    allowed to impersonate the state service account via
    roles/iam.serviceAccountTokenCreator. Empty string defers CI binding —
    see docs/workload-identity-federation.md. No SA JSON keys in CI, ever.
  EOT
  type        = string
  default     = ""
}

variable "labels" {
  description = "Additional labels merged onto the bucket."
  type        = map(string)
  default     = {}
}
