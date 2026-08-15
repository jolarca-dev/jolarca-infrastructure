variable "org" {
  description = "GitHub organization name (marketplace scope lives in the same org but is scope-segregated by repo set)."
  type        = string
  default     = "journeyoflife-org"
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
  # MARKETPLACE fleet (jol-m-*) only. Mission-platform repos (jol-*) must
  # never appear here; mixing PCI-scoped marketplace state with mission
  # governance is a compliance boundary violation (and the CI fleet guard
  # scripts/check-fleet-separation.sh enforces the reverse direction).
  validation {
    condition     = alltrue([for name, _ in var.repositories : can(regex("^jol-m-[a-z0-9][a-z0-9-]{0,50}$", name))])
    error_message = "All fleet repositories must be named jol-m-* (ADR-0004 mission/marketplace separation)."
  }

  default = {
    jol-m-marketplace = {
      description      = "Marketplace platform application code (PCI-DSS payments, KYC/AML, VAT OSS scope)."
      visibility       = "public"
      license_template = "agpl-3.0"
    }
    jol-m-infrastructure = {
      description = "Marketplace infrastructure-as-code and provisioning (scope-segregated from church-platform infra)."
      visibility  = "private"
    }
    jol-m-compliance = {
      description = "Marketplace compliance evidence and audit records (ISO 27001 / SOC 2 / PCI-DSS)."
      visibility  = "private"
    }
    jol-m-legal = {
      description = "Marketplace legal artifacts: contracts, terms, privacy notices, VAT OSS filings."
      visibility  = "private"
    }
    jol-m-data = {
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
