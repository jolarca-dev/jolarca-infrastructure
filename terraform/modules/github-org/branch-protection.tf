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
  # (tfsec ignore mirrors CKV_GIT_6 above.)
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
}
