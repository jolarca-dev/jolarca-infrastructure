# terraform/bootstrap — one-time state-custody bootstrap (ADR-0003).
#
# Chicken-and-egg: the state buckets must exist BEFORE any environment can
# use a remote backend, so this root runs on LOCAL state, once per
# environment, under a human-gated change window. Procedure of record:
# docs/runbooks/bootstrap-state-backend.md.
#
# Isolation: the workspace SELECTS the environment; there is no way to
# apply both environments from one state file.
#
# Auth: `gcloud auth application-default login` (operator identity) —
# never an SA JSON key, never committed credentials.

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  environment = terraform.workspace

  # Bucket names are FROZEN: they are already referenced from
  # terraform/backends/*.backend.hcl. Changing a name here without the
  # matching backend file is a state-loss incident.
  environments = {
    staging = {
      bucket_name    = "jolm-tfstate-staging-3c4a45"
      retention_days = 0 # staging: versioning is the undo lever
      lock_retention = false
    }
    production = {
      bucket_name    = "jolm-tfstate-production-857941"
      retention_days = 90
      lock_retention = true # IRREVERSIBLE — production doctrine
    }
  }
}

# Workspace guard: plan/apply refuses any workspace other than
# staging|production (ADR-0002 isolation — one custody stack per state).
resource "terraform_data" "workspace_guard" {
  lifecycle {
    precondition {
      condition     = contains(keys(local.environments), terraform.workspace)
      error_message = "workspace must be 'staging' or 'production' (terraform workspace select <env>)."
    }
  }
}

module "state_bucket" {
  source = "../modules/state-bucket"

  environment    = local.environment
  project_id     = var.project_id
  region         = var.region
  bucket_name    = local.environments[local.environment].bucket_name
  retention_days = local.environments[local.environment].retention_days
  lock_retention = local.environments[local.environment].lock_retention
  ci_principal   = var.ci_principal
}
