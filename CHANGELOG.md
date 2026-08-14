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
