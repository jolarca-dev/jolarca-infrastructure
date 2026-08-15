# Version pins for the state-bucket module.
# Provider hash pinning (.terraform.lock.hcl at the consuming root) is a
# supply-chain control (SOC 2 CC7.1); the google provider pin mirrors
# environments/staging/versions.tf — staging soaks upgrades first.

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}
