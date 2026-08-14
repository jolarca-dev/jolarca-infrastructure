# Changelog — jol-m-infrastructure

All notable changes to this infrastructure repository are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
commits follow Conventional Commits. Infra changes are auditable history
(SOC 2 CC8.1) — never rewrite released entries.

## [Unreleased]

### Added

- Repository scaffold: 90/10 Moat structure (terraform / ansible /
  kubernetes / backup / monitoring / security / docs / scripts).
- Root compliance baseline: README, LICENSE (internal use only),
  SECURITY.md, CONTRIBUTING.md (plan-first, two-person rule),
  Makefile, pre-commit (gitleaks, terraform fmt/validate, checkov).
- CI/CD: terraform pipeline (fmt → validate → tflint → checkov → plan →
  gated apply), security scan, scheduled drift detection.
- Terraform: GCS backend definitions (staging/production, isolated),
  staging environment skeleton, OPA/Rego policies (no public IPs, no basic
  IAM roles, CMEK required), reserved module placeholders.
- Governance docs: isolation model, network policy, CIS baseline, key
  custody, PCI-DSS scope, access-review template.
- ADR-0001 (90/10 split), ADR-0002 (state isolation), ADR-0003 (encrypted
  remote state migration — proposed).
- Runbook skeletons incl. GitHub token rotation and state compromise.

### Changed

- Renamed `terraform/environments/prod/` to `terraform/environments/production/`
  for consistent environment naming before remote-state migration.
- Imported the out-of-band-created `jol-m-infrastructure` repository into
  production Terraform state (`github_repository` +
  `github_repository_vulnerability_alerts`); pending reconciliation:
  merge-method policy, delete-branch-on-merge, Dependabot alerts enablement.
- `scripts/audit-no-secrets.sh`: added a documented, removable exception for
  the canonical local-backend state paths while `backend "local"` is the
  declared custody (ADR-0003 pending). All other state locations remain
  forbidden. Shellcheck-clean.
- CI credential plane wired: repo secret `TF_GITHUB_TOKEN_READONLY`,
  environment secret `TF_GITHUB_TOKEN_WRITE` on `production`, and the
  `staging-readonly` environment created. Secrets are repo-scoped by
  design; interim deviations (shared classic PAT, no environment approval
  gate on the current plan) documented in security/key-custody.md.
- Solo-era operating model adopted (single operator): human review gates
  deferred (review count 0, CODEOWNERS reviews off in the production root
  module override), automated gates (required ci/security status checks)
  remain mandatory. Onboarding trigger for the second operator documented
  in CONTRIBUTING.md; deviation tracked in security/key-custody.md. No
  billing-plan upgrade required or planned.
- CI pipeline stabilized to green on main: real action SHAs, codeql
  checkout permissions, compliance grep false positive fixed, gitleaks
  moved to the pinned free CLI (the action became license-gated),
  documented checkov/tfsec skips for intentionally-public repos and
  for_each-linked resources.
- Scanners rationalized: tfsec removed (archived upstream, rule set lives
  on in the Trivy config scan that runs in the same workflow); CodeQL
  disabled (.yml.disabled) because code scanning on private repos needs
  GitHub Advanced Security — re-enable condition documented in the file.
  Both removals leave no coverage hole: Trivy covers IaC misconfiguration,
  yamllint/shellcheck/pinned-action review cover pipeline definitions.
