variable "org" {
  description = "GitHub organization name for the marketplace scope."
  type        = string
  # CORRECTED 2026-09-25 (jolarca-control docs/drift-findings.md D-06). Was
  # "journeyoflife-org", which has been wrong since the 2026-09-02 org transfer
  # that moved all five jolarca* repositories to jolarca-dev. The provider
  # `owner` follows this value, so every plan run against the old default was
  # addressing the mission-platform org — where these names survive only as
  # 2-hop redirect stubs.
  #
  # NOTE: the live terraform.tfstate was last written 2026-08-31, BEFORE the
  # transfer, so its full_name attributes still read journeyoflife-org/*.
  # Correcting this variable makes config agree with reality; it does NOT
  # repair the state. See the migration runbook in jolarca-control.
  default = "jolarca-dev"
}

variable "repositories" {
  description = "Marketplace Tier-1 repository fleet: name -> {description, visibility, optional license_template/auto_init}."
  type = map(object({
    description      = string
    visibility       = string
    license_template = optional(string)
    auto_init        = optional(bool, true)
  }))

  # ADR-0004 R1/R3 — project separation: this module's jurisdiction is the
  # MARKETPLACE fleet (jolarca*) only. Mission-platform repos (jol-*) must
  # never appear here; mixing PCI-scoped marketplace state with mission
  # governance is a compliance boundary violation (and the CI fleet guard
  # scripts/check-fleet-separation.sh enforces the reverse direction).
  # ADR-0005: jol-hub (mission-program flagship, payment-API consumer) is
  # deliberately absent from this map — its creation/management belongs to
  # mission-program IaC; mission resources must never enter this state.
  validation {
    condition     = alltrue([for name, _ in var.repositories : can(regex("^jolarca(-[a-z0-9-]+)?$", name))])
    error_message = "All fleet repositories must be named jolarca or jolarca-<suffix> (ADR-0004 mission/marketplace separation)."
  }

  default = {
    jolarca = {
      description      = "Marketplace platform application code (PCI-DSS payments, KYC/AML, VAT OSS scope)."
      visibility       = "public"
      license_template = "agpl-3.0"
    }
    jolarca-infrastructure = {
      description = "Marketplace infrastructure-as-code and provisioning (scope-segregated from church-platform infra)."
      visibility  = "private"
    }
    jolarca-compliance = {
      description = "Marketplace compliance evidence and audit records (ISO 27001 / SOC 2 / PCI-DSS)."
      visibility  = "private"
    }
    jolarca-legal = {
      description = "Marketplace legal artifacts: contracts, terms, privacy notices, VAT OSS filings."
      visibility  = "private"
    }
    jolarca-data = {
      description = "Marketplace data schemas and migrations (no production data in git)."
      visibility  = "private"
    }
  }
}

variable "protected_branch_pattern" {
  description = "Branch pattern protected in every managed repo."
  type        = string
  default     = "main"
}

variable "required_approving_review_count" {
  description = "Approving reviews required before merge."
  type        = number
  default     = 1
}

variable "require_code_owner_reviews" {
  description = "Enforce CODEOWNERS approval on protected branches."
  type        = bool
  default     = true
}

variable "required_status_checks" {
  description = "Status check contexts that must pass before merge (CI + security)."
  type        = list(string)
  default     = ["ci", "security"]
}

variable "org_security_policy_content" {
  description = "Content for the org-wide SECURITY.md in the .github repo. Empty string defers file creation."
  type        = string
  default     = ""
  sensitive   = false
}

variable "enable_branch_protection" {
  description = "Two-phase bootstrap gate: false = phase 1 (create repos unprotected so scaffold/workflows can be seeded); true = phase 2 (apply branch protection)."
  type        = bool
  default     = true
}
