# terraform/modules/github-org — GitHub organization baseline for the marketplace scope.
#
# Compliance: ISO 27001:2022 A.8.13 (separation of information processing —
# marketplace repos live in their own scope, distinct from the church-platform
# jol-infrastructure repo), SOC 2 CC6.1 (logical access: branch protection,
# review gates, no force-push), SOC 2 CC8.1 (change management via PR+CI).
#
# Least-privilege note (STOP-IF verified): the provider calls used here
# (repos CRUD, branch protection, file content) require the classic 'repo'
# scope plus 'read:org' for org lookups only. No admin:org scopes needed.

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}
