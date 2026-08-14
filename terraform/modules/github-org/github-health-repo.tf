# Organization-level community health repo. GitHub serves SECURITY.md (and
# other community health files) from this repo to every org repo that lacks
# its own copy — this is how "SECURITY.md inherited from org .github repo"
# is realized; no per-repo resource is needed for the inheritance itself.
resource "github_repository" "dot_github" {
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
