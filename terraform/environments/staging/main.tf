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
# NO backend block — remote GCS state (ADR-0003) lands in two phases:
# migration window uses the gitignored zz-remote-backend.tmp.tf overlay;
# the permanent block arrives with the post-migration PR + TF_REMOTE_STATE
# flip. Params: ../../backends/staging.backend.hcl. Runbook:
# ../../docs/runbooks/bootstrap-state-backend.md

variable "environment" {
  description = "Environment name (guardrail: modules may assert on this)."
  type        = string
  default     = "staging"
}

output "environment" {
  value = var.environment
}
