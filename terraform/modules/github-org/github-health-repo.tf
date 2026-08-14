# Organization-level community health repo. GitHub serves SECURITY.md (and
# other community health files) from this repo to every org repo that lacks
# its own copy — this is how "SECURITY.md inherited from org .github repo"
# is realized; no per-repo resource is needed for the inheritance itself.
#trivy:ignore:GIT-0001 trivy:ignore:GIT-0003
resource "github_repository" "dot_github" {
  # checkov:skip=CKV_GIT_1: must be public — GitHub only serves org-wide
  # community health files from a public .github repository.
  # checkov:skip=CKV2_GIT_1: content-only health repo; excluded from the
  # fleet branch-protection map by design (no code, no CI).
  //tfsec:ignore:github-repositories-private
  //tfsec:ignore:github-repositories-enable_vulnerability_alerts
  # (tfsec/trivy ignores mirror the checkov skips documented above.)
  name        = ".github"
  description = "Organization default community health files (SECURITY.md, CODE_OF_CONDUCT.md)"
  visibility  = "public"
  auto_init   = true
}

# SECURITY.md content is applied once org_security_policy_content is set
# (empty string = file creation deferred; avoids shipping placeholder policy).
resource "github_repository_file" "security_md" {
  count = var.org_security_policy_content != "" ? 1 : 0

  repository = github_repository.dot_github.name
  file       = "SECURITY.md"
  content    = var.org_security_policy_content
  branch     = "main"

  commit_author  = "jolm-infra-automation"
  commit_email   = "jolm-infra-automation@users.noreply.github.com"
  commit_message = "docs(security): org default SECURITY.md"

  overwrite_on_create = false
}
