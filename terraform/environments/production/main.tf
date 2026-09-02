# Root configuration — marketplace GitHub org baseline (production scope).
# Compliance: ISO 27001 A.8.13, SOC 2 CC6.1/CC8.1.
#
# This file manages:
#   1. GitHub org governance (existing — live)
#   2. Proxmox VMs/LXCs (90% plane — lands after staging validation)
#   3. GCP resources (10% plane — lands after staging validation)
#
# Token handling: GITHUB_TOKEN is read from the operator's environment by the
# provider. Never commit a token; secrets belong in Vaultwarden, not tfvars.
#
# PRODUCTION DOCTRINE: Proxmox and GCP resources are commented out until
# the staging environment has validated the modules. Uncomment and apply
# only after staging soak is complete.

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.66.0, < 1.0.0"
    }
  }

  # NO backend block — doctrine hardened by experience (ADR-0003).
  # Remote GCS state lands via the migration window procedure.
  # Params: ../../backends/production.backend.hcl
}

# ── GitHub org governance (LIVE) ────────────────────────────────────────

provider "github" {
  owner = var.org
}

module "github_org" {
  source = "../../modules/github-org"

  org = var.org

  enable_branch_protection = var.enable_branch_protection

  # SOLO-ERA DEVIATION (tracked: security/key-custody.md)
  required_approving_review_count = 0
  require_code_owner_reviews      = false
}

# ── Proxmox provider (COMMENTED — lands after staging validation) ───────

# provider "proxmox" {
#   endpoint = var.proxmox_endpoint
#   insecure = var.proxmox_insecure
# }

# ── Proxmox VMs (COMMENTED — lands after staging validation) ────────────
# Uncomment and apply after staging soak. VMIDs match PROXMOX_DEPLOYMENT_PLAN.md
# but with production-appropriate sizing (higher CPU/RAM/disk).

# module "edge_vm" {
#   source = "../../modules/proxmox-vm"
#   name   = "edge-production"
#   vm_id  = 1000  # Production VMIDs start at 1000
#   ...
# }

# ── GCP provider (COMMENTED — lands after staging validation) ───────────

# provider "google" {
#   project = var.project
#   region  = var.region
# }

# ── GCP networking (COMMENTED — lands after staging validation) ─────────

# module "networking" {
#   source = "../../modules/networking"
#   ...
# }

# ── GKE (COMMENTED — lands after staging validation) ────────────────────

# module "gke" {
#   source = "../../modules/gke"
#   ...
# }

# ── Outputs ─────────────────────────────────────────────────────────────

output "repositories" {
  value = module.github_org.repositories
}

output "health_repo" {
  value = module.github_org.health_repo
}

output "note" {
  value = "production: GitHub org LIVE; Proxmox + GCP modules ready but commented until staging validation completes"
}
