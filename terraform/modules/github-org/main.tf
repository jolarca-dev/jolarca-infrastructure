# Marketplace Tier-1 repository fleet. Visibility and license are declared
# here and enforced by terraform — drift corrected on every apply.
resource "github_repository" "repos" {
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
