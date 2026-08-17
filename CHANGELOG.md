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
- STEP 0 (ADR-0003): `terraform/modules/state-bucket/` implemented —
  CMEK keyring/key (90-day rotation), versioned state bucket (uniform
  access, public-access prevention, soft delete, optional retention
  lock), dedicated state SA, WIF impersonation binding, GCS audit
  logging; `terraform/bootstrap/` chicken-and-egg root (workspace per
  environment, local state by design).
- Backend configs completed (`backends/*.backend.hcl`, frozen bucket
  names). Environments stay backend-free until the phase-B PR — any
  declared backend breaks `init -backend=false` CI dry plans (proven by
  PR #5); the migration window uses the gitignored
  `zz-remote-backend.tmp.tf` overlay (runbook steps 3/6/9).
- Runbooks/docs: `docs/runbooks/bootstrap-state-backend.md` (procedure
  of record), `docs/workload-identity-federation.md` (CI auth without
  SA keys), `STEP0_VERIFICATION.md` (operator gate checklist).
- ADR-0004 mission/marketplace separation doctrine with enforceable
  rules: `jol-m-*` prefix covenant, Terraform-only repo creation (48h
  out-of-band import incident rule), module validation rejecting
  non-marketplace fleet keys, `scripts/check-fleet-separation.sh` +
  `fleet-separation-guard.yml` weekly/on-change CI guard, `marketplace`
  topic marking on the five fleet repos.
- STEP 10 payment boundary (operator-ratified Model A): ADR-0005 two
  Django projects + single payment boundary (one Stripe integration in
  the marketplace `payments_app`; jol-hub is a client of the boundary;
  PCI scope = the boundary only; Model B rejection recorded), the
  payment API integration contract (`docs/payment-api-contract.md`),
  ADR-0004 Amendment 1 (the single sanctioned cross-program exception),
  `scripts/check-payment-boundary.sh` guard (E1; shellcheck-clean,
  negative-tested), payment-boundary egress matrix in
  `security/network-policy.md` (E3), hub out-of-scope note in
  `security/pci-dss-scope.md`, isolation-model boundary-1 note, and
  `STEP10_PAYMENT_BOUNDARY.md` gate record. jol-hub fleet placement
  documented (mission flagship, `/opt/jol/repos/`, mission-program IaC
  custody — deliberately absent from the marketplace `github-org`
  module). Architecture only; no payment code.
- STEP 17 independent payment-boundary audit (`STEP17_AUDIT.md`):
  per-control verdicts with reproduced evidence — hostile hub→Stripe
  attempt blocked (no valid credential fleet-wide, no hub code path),
  marketplace Stripe usage contained to payments_app; findings PB-01…
  PB-06 (dormant Model-B residue in jol-hub), E1/E2 guards not yet
  wired in hub CI, E3 not deployed, internal API unimplemented. SAQ-A
  scope statement + archived evidence filed in jol-m-compliance;
  residuals owned as RSK-006…RSK-011. Verdict: Model A NOT PROVEN yet.
- STEP 22 payment-boundary re-audit (`STEP22_REAUDIT.md`): premise
  "Steps 18–21 implemented" REJECTED — no step artifacts, no
  remediation commits in any repo, no live boundary; every STEP-17
  finding reproduces byte-identically (PB-01…PB-06, webhook 500-vs-400
  defect, missing product attribution and /internal/v1); hostile attempt
  still blocked by credential absence, not topology; only deltas: hub's
  correct-but-undeployed default-deny NetworkPolicy manifests and 0 real
  keys fleet-wide. New findings N1–N3; blockers B1–B8 owned; G3 NOT
  cleared; scope statement and risk register deliberately unchanged
  (certifying PROVEN now would be false attestation).
- STEP 22B final re-audit attempt (`STEP22B_FINAL_REAUDIT.md`): STOPPED
  at the premise gate — Steps 18–21 artifacts absent, no remediation
  commits in any repo, no live boundary (test-db/redis only, no
  cluster); drift spot-check byte-identical to STEP 22 (PB-01/02/05,
  webhook defect, missing product field). Nothing attested, G3 still
  BLOCKED, blockers B1–B8 unchanged; N3 evidence-custody gap persists.
- STEP 21 payment-boundary E3 staging (execution): N2 hub→payment-API
  egress row merged fail-closed (jol-hub PR #82),
  `scripts/e3-network-deny-test.sh` record copy (credential-independent
  deny proven on the staging plane; positives green), network-policy
  matrix status column + drift-alerting section,
  `docs/payment-boundary-enforcement.md` ledger updated for steps
  18–21, `STEP21_EXECUTED.md` + `EXECUTION_BUNDLE_18-21.md` evidence
  bundle. Staging only; production human-gated.
- STEP 22C final independent re-audit (`STEP22C_FINAL_REAUDIT.md`):
  premise PASSED (all four merge SHAs + STEPn_EXECUTED.md committed);
  every control reproduced with zero inherited claims — PB-01…06 clean,
  fleet entropy scan 0 keys, fresh negative-test PR jol-hub #83 blocked
  on normal AND admin merge paths (HTTP 405 rule violation), E3
  credential-independent deny re-run green, contract suite 14/14 live.
  Verdict: Model A PROVEN, hub out of PCI scope. G3 CONDITIONAL
  CLEARANCE: payment-boundary controls cleared; first-real-donation
  authorization withheld pending DPIA-003 signature, VIES VAT evidence,
  Stripe TIA + AoC, RSK-013 (contract suite ungated in boundary-repo CI)
  and RSK-014 (refund PSP wiring). Enforcement ledger updated.

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
- ADR-0003 accepted (was Proposed): GCS + CMEK decision, alternatives,
  rollback procedure.
- CI: `drift-detection.yml` and `terraform.yml` apply job are
  backend-aware behind the `TF_REMOTE_STATE` repository-variable gate
  (WIF auth, state-SA impersonation); drift exit code now actually
  captured; validate job covers `terraform/bootstrap/` + state-bucket
  module (checkov).
- `scripts/check-drift.sh` supports `TF_REMOTE_STATE=true` (same logic
  as CI); `scripts/bootstrap.sh` checklist aligned with the runbook.
