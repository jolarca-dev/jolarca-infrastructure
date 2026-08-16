# CHANGES.md — auto-fixes applied during 2026-08-infra-audit

Audit rule: auto-fix is permitted only for TRIVIAL findings (typos, dead links, fmt),
and every applied fix must be logged here. Everything else is report-only.

## Applied auto-fixes

**None.**

## Evaluated and rejected for auto-fix (reported instead)

| Item | Why not auto-fixed |
|---|---|
| `scripts/audit-no-secrets.sh` missing WireGuard pattern (F-01) | Functional change to a security gate — requires security review, not a trivial fix |
| `scripts/audit-no-secrets.sh` `.venv` false positives (F-02) | Functional change to a security gate; behavior in CI already correct |
| `drift-detection.yml` missing `exitcode` output (F-03) | Workflow logic change — report-first per audit mandate |
| `no-basic-iam-roles.rego` dead rule (F-06) | Policy change — requires security owner review |
| `jol-m-*` → canonical naming (F-09) | Repo rename + fleet-map change is a managed change record, not a fix |

## Verification status of the tree

- `terraform fmt -check -recursive`: clean (no fmt fixes needed)
- Dead-link scan over all `*.md`: no dead links (no link fixes needed)
- Typo sweep of governance docs: none found

Audit branch: `audit/2026-08-infra` · Audit ID: `2026-08-infra-audit`
