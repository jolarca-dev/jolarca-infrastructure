# Staging environment variables.
# Keep the surface minimal: defaults live in modules, overrides land here
# only when staging intentionally deviates from production shape.

variable "project" {
  description = "GCP project for the marketplace staging scope (lands with the GCP workstream)."
  type        = string
  default     = ""
}

variable "region" {
  description = "Primary region. EU residency is mandatory for data-plane resources (GDPR Art. 44, PCI-DSS scope containment)."
  type        = string
  default     = "europe-west1"
}
