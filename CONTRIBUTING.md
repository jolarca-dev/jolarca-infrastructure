# Contributing — jolarca-infrastructure

Operators only. This repository changes production infrastructure; every
merge is a change-management record (SOC 2 CC8.1, ISO 27001 A.8.32).

## Workflow: plan-first

1. **Issue first.** Open a change request (`change_request.yml`) stating
   risk class, blast radius, and rollback plan. Infrastructure changes
   without these three fields are closed.
2. **Plan before apply.** Terraform changes ship with `terraform plan`
   output attached to the PR. No "apply-first, plan-later".
3. **Small, reviewable diffs.** One concern per PR.
4. **CI is a merge gate.** `ci`, `security`, and terraform checks must be
   green; branch protection enforces this including for administrators.

## The two-person rule

Production-affecting and security-sensitive paths require review beyond the
author. CODEOWNERS routes reviews; branch protection sets the required
approving count. The author never self-approves.

**Solo-era operation (current):** the org has exactly one operator, so
human review gates are deferred — an author cannot approve their own PR,
and a review requirement would lock the sole maintainer out. Enforcement
rides entirely on the automated gates: required `ci` + `security` status
checks, plan-first workflow, and daily drift detection. This is a tracked
deviation (`security/key-custody.md`), not an exemption: the rule and
CODEOWNERS routing stay in place and activate when the second operator
onboards.

**Onboarding trigger (second operator):** add to `@security`/operators
teams, set `required_approving_review_count >= 1` and re-enable CODEOWNERS
reviews in `terraform/environments/production/main.tf`, split the interim
shared PAT (issue on file), then record the change in the access review.

Security-sensitive paths (non-exhaustive): `terraform/backends/`,
`terraform/policies/`, `ansible/vault/`, `security/`, `scripts/`,
`.github/workflows/`, `kubernetes/policies/`.

## Change-risk classes

| Class | Examples                                        | Gate                          |
|-------|-------------------------------------------------|-------------------------------|
| Low   | Docs, comments, reserved scaffolding            | 1 review                      |
| Med   | Non-prod resource changes, module refactors     | 1 review + plan attached      |
| High  | Prod resources, IAM, network, state custody     | 2-person rule + rollback plan |
| Crit  | State migration, secret rotation, destroy paths | 2-person rule + change window |

## Secrets — never in git

- No tokens, keys, PEMs, vault password files, or `.tfstate` — enforced by
  `.gitignore`, pre-commit (gitleaks), and `scripts/audit-no-secrets.sh`.
- Runtime credentials come from the operator environment or Vaultwarden.
- Ansible secrets (when the workstream lands) are `ansible-vault` encrypted
  with per-environment passwords under dual control.

## Local hygiene

```bash
make fmt lint check
```

Pre-commit hooks run gitleaks, terraform fmt/validate, and lint checks;
install once with `pre-commit install`.

## Rollback

Every PR must state how to revert it. For Terraform: the inverse plan or
restored state version. For Ansible (later): idempotent revert playbook or
restore-from-backup reference. If you cannot describe the rollback, the
change is not ready.
