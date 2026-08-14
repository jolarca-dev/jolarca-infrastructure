# Staging environment — non-prod proving ground.
#
# Purpose: validate IaC changes, module upgrades, and provider version bumps
# against a real (non-production) control plane before they reach
# ../production. State is ISOLATED (ADR-0002): this environment must never
# reference the production backend.
#
# Compliance: ISO 27001 A.8.31 (separation of dev/test/production).
#
# Provider/version pins live in versions.tf (single source of truth).
# Backend stays local/disabled until the state-bucket workstream lands;
# flip to GCS via ADR-0003 using backends/staging.backend.hcl.
# (No explicit backend block: the implicit local default keeps CI dry
# plans working with `init -backend=false`.)

# GitHub-org governance is org-global (one org), so staging does NOT manage
# the repository fleet — that belongs to production only. Staging instead
# exercises GCP modules (networking/iam/gke/dns) once they land.
#
# Nothing to manage yet: the GCP workstream populates this file.

variable "environment" {
  description = "Environment name (guardrail: modules may assert on this)."
  type        = string
  default     = "staging"
}

output "environment" {
  value = var.environment
}
