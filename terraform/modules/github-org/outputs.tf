output "repositories" {
  description = "Managed marketplace repositories (full name and URL)."
  value = {
    for name, repo in github_repository.repos :
    name => { full_name = repo.full_name, html_url = repo.html_url, visibility = repo.visibility }
  }
}

output "health_repo" {
  description = "Org community-health repo serving the inherited SECURITY.md."
  value       = github_repository.dot_github.html_url
}

output "branch_protection" {
  description = "Branch protection rule IDs per repo."
  value = {
    for name, bp in github_branch_protection.main : name => bp.id
  }
}
