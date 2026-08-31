# Marketplace Tier-1 repository fleet. Visibility and license are declared
# here and enforced by terraform — drift corrected on every apply.
#trivy:ignore:GIT-0001 trivy:ignore:GIT-0003
resource "github_repository" "repos" {
  # checkov:skip=CKV_GIT_1: jolarca is INTENTIONALLY public — it
  # is the open-source marketplace application (AGPL-3.0). The
  # infrastructure, compliance, legal, and data repos in this fleet are
  # private. Visibility is a deliberate per-repo policy decision.
  # checkov:skip=CKV2_GIT_1: branch protection IS declared for every repo
  # in this map via github_branch_protection.main (branch-protection.tf,
  # for_each over the same variable); checkov cannot follow the for_each
  # linkage. Two-phase bootstrap may temporarily leave repos unprotected.
  # checkov:skip=CKV_GIT_3: Dependabot vulnerability alerts ARE enabled for
  # every repo in this map via github_repository_vulnerability_alerts.repos
  # (for_each over the same variable); checkov cannot follow the linkage.
  //tfsec:ignore:github-repositories-private
  //tfsec:ignore:github-repositories-enable_vulnerability_alerts
  # (tfsec/trivy ignores mirror the checkov skips documented above.)
  for_each = var.repositories

  name        = each.key
  description = each.value.description
  visibility  = each.value.visibility

  license_template = lookup(each.value, "license_template", null)
  auto_init        = lookup(each.value, "auto_init", true)

  allow_merge_commit = false
  allow_squash_merge = true
  allow_rebase_merge = false
  allow_auto_merge   = false

  delete_branch_on_merge = true

  # Note: has_issues/has_wiki/has_projects are managed by the provider at
  # their defaults; tighten in a follow-up once workflow needs are settled.
}

# Dependency scanning (Dependabot alerts) on every managed repo.
resource "github_repository_vulnerability_alerts" "repos" {
  for_each = var.repositories

  repository = github_repository.repos[each.key].name
  enabled    = true
}
