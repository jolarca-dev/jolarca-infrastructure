# Root configuration — marketplace GitHub org baseline (production scope).
# Compliance: ISO 27001 A.8.13, SOC 2 CC6.1/CC8.1.
#
# Environment naming: this directory was renamed prod/ -> production/ for
# consistency with staging/ (see CHANGELOG.md).
#
# Token handling: GITHUB_TOKEN is read from the operator's environment by the
# provider (gh-authenticated shell). Never commit a token; secrets belong in
# Vaultwarden, not in tfvars or state.

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  # Local backend for the initial bootstrap. Migration to encrypted GCS
  # state is tracked by ADR-0003 (this repo) using backends/production
  # .backend.hcl; state contains no secrets, only repo/protection metadata.
  backend "local" {}
}

provider "github" {
  owner = var.org
  # token sourced from GITHUB_TOKEN / GH_TOKEN environment — never set here
}

variable "org" {
  description = "GitHub organization."
  type        = string
  default     = "journeyoflife-org"
}

variable "enable_branch_protection" {
  description = "Two-phase bootstrap gate: run phase 1 with -var=enable_branch_protection=false, phase 2 with the default (true)."
  type        = bool
  default     = true
}

module "github_org" {
  source = "../../modules/github-org"

  org = var.org

  enable_branch_protection = var.enable_branch_protection

  # Fleet, protection policy, and status-check contexts come from module
  # defaults; override here only when the marketplace policy changes.
}

output "repositories" {
  value = module.github_org.repositories
}

output "health_repo" {
  value = module.github_org.health_repo
}
