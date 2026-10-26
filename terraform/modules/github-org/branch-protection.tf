# Branch protection for the default branch of every managed repo.
# SOC 2 CC6.1/CC8.1: 1 approving review, CODEOWNERS review enforced,
# required CI + security status checks, no force-push, no deletion,
# rules apply to administrators as well.
#
# Two-phase bootstrap: with enable_branch_protection=false (phase 1) the
# repos are created unprotected so the initial scaffold + workflow content
# can be seeded; phase 2 flips the flag and protection applies. Note that
# required status checks will block ALL PRs until matching workflows exist,
# so phase 2 must land together with (or after) the first workflow PRs.
#trivy:ignore:GIT-0004
resource "github_branch_protection" "main" {
  # checkov:skip=CKV_GIT_5: SOLO-ERA DEVIATION (tracked:
  # security/key-custody.md, CONTRIBUTING.md). With one operator, 2 — or
  # even 1 — approving reviews are unsatisfiable and would lock the sole
  # maintainer out. Enforcement rides on required status checks below.
  # REMOVE this skip and raise the review count when the second operator
  # onboards.
  # checkov:skip=CKV_GIT_6: signed commits not required because provider-
  # seeded automation commits (github_repository_file, jolm-infra-
  # automation) cannot be GPG-signed; revisit if commit-signing infra for
  # automation lands.
  //tfsec:ignore:github-branch_protections-require_signed_commits
  # (tfsec/trivy ignores mirror CKV_GIT_6 above.)
  for_each = var.enable_branch_protection ? var.repositories : {}

  repository_id = github_repository.repos[each.key].name
  pattern       = var.protected_branch_pattern

  required_pull_request_reviews {
    required_approving_review_count = var.required_approving_review_count
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = var.require_code_owner_reviews
  }

  required_status_checks {
    strict   = false
    contexts = var.required_status_checks
  }

  enforce_admins                  = true
  allows_force_pushes             = false
  allows_deletions                = false
  require_conversation_resolution = true

  # ADDED 2026-09-25 while this root is FROZEN (D-13).
  #
  # STATE/CONFIG MISMATCH — read before planning (D-08). This for_each covers
  # all five repos, but the live state holds a rule for `jolarca` ONLY. All six
  # repos do have protection on GitHub — it was applied out-of-band via
  # `gh api` during the 2026-09-17 delivery-chain audit. A plan from this root
  # would therefore propose CREATING four rules that already exist, and GitHub
  # permits only one protection rule per branch pattern, so it would fail with
  # a conflict. Do not "fix" that by deleting the live rules.
  #
  # Also note this module passes require_code_owner_reviews = false from
  # environments/production/main.tf while the live value is TRUE on all five
  # jolarca* repos. Applying from here would have silently WEAKENED CODEOWNERS
  # enforcement. jolarca-control encodes the verified live value instead.
  lifecycle {
    prevent_destroy = true
  }
}
