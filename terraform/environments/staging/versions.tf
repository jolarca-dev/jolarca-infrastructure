# Version pins for the staging environment.
# .terraform.lock.hcl MUST be committed alongside this file: provider hash
# pinning is a supply-chain control (SOC 2 CC7.1). Bumps go through PR
# review; staging is upgraded FIRST, production only after a soak period.

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
}
