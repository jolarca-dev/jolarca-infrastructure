# terraform/modules/github-org — GitHub organization baseline for the marketplace scope.
#
# ══════════════════════════════════════════════════════════════════════════
# FROZEN — SUPERSEDED BY jolarca-control (2026-09-25)
# ══════════════════════════════════════════════════════════════════════════
# GitHub-organization governance for jolarca-dev has been extracted into its
# own control-plane repository: jolarca-dev/jolarca-control. That repo declares
# the same resources from a repos/*.yml allow-list instead of the variable
# default below.
#
# DO NOT run terraform plan / apply / destroy from
# terraform/environments/production while this module is still wired. Reasons:
#   1. D-13 dual ownership — jolarca-control now declares the same live repos.
#   2. D-08 — the branch-protection for_each covers five repos but state holds
#      one, so a plan proposes creating four rules that already exist on
#      GitHub. That fails with a conflict; it must not be "resolved" by
#      deleting live protection.
#   3. D-03 — state for github_repository.dot_github points at
#      journeyoflife-org/.github, a MISSION-platform repo. See the warning in
#      github-health-repo.tf.
#   4. var.org was wrong until 2026-09-25 (D-06) and the state predates the
#      2026-09-02 org transfer, so state and config disagree on which org
#      owns these repos.
#
# The correct path is jolarca-control/docs/state-migration-runbook.md, which
# moves the state with `state rm` + `import` (never destroy/recreate) and
# retires this module in the same change window. Step 0 of that runbook —
# an off-host verified backup of terraform.tfstate — has not been done (D-02).
#
# This module is retained, not deleted, because deleting the config without
# first moving the state would orphan five repository entries and make the
# next plan propose destroying real repositories.
# ══════════════════════════════════════════════════════════════════════════
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
