# Bootstrap root inputs.
# project_id is operator-supplied at runtime (TF_VAR_project_id or -var):
# it is environment-specific and must never be hardcoded here (production
# values travel as operator-supplied variables — STEP 0 constraint).

variable "project_id" {
  description = "GCP project for the selected workspace's state custody stack. Supply via TF_VAR_project_id."
  type        = string

  validation {
    condition     = length(var.project_id) > 0
    error_message = "project_id must be supplied (TF_VAR_project_id); it is never committed."
  }
}

variable "region" {
  description = "GCP region for buckets and KMS keyrings."
  type        = string
  default     = "europe-west1"
}

variable "ci_principal" {
  description = "WIF principal for CI impersonation; deferred (empty) until docs/workload-identity-federation.md lands."
  type        = string
  default     = ""
}
