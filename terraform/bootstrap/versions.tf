# Version pins for the bootstrap root (state-bucket chicken-and-egg step).
# Mirrors modules/state-bucket/versions.tf. The bootstrap root keeps LOCAL
# state by design (ADR-0003 runbook); it never references a remote backend.

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}
