# Delivery-Chain and Security Audit — All jolarca-dev Repositories — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Verify and, where required, remediate the full `branch → commit → push → Pull Request → CI → merge → main` chain plus security controls across all six `jolarca-dev` repositories, ending with machine-checked evidence.

**Architecture:** Read-only capture first (no config change without a captured baseline), then three remediation lanes: (A) code defects that reached `main`, (B) the CI gate that let them through, (C) the open-PR/dependency backlog. Every change lands through a signed-commit PR, squash-merged, then re-verified org-wide.

**Tech Stack:** GitHub CLI (`gh`), classic branch protection + status checks, GitHub Actions (ansible/ci/security-scan/compliance-check/terraform/drift-detection/fleet-separation-guard), pre-commit 4.6.2 in `/opt/jolarca/repos/jolarca-infrastructure/.venv`, gitleaks v8.21.2, terraform/checkov/tflint, ansible-lint.

**Repos in scope:** `jolarca`, `jolarca-infrastructure`, `jolarca-compliance`, `jolarca-data`, `jolarca-legal`, `.github`

**Verified baseline (unauthenticated, 2026-09-17):** 23 open PRs org-wide (20 in `jolarca`, 3 in `jolarca-infrastructure`), 0 failed workflow runs on `main` in all five code repos, six public repos, no rulesets.

**Non-negotiable mechanics (verified in prior sessions, still binding):**
- `gh api .../branches/main/protection -X PUT` requires a JSON body via `--input` (form `-f` flags fail with "'false' is not a boolean") **and** must include `"restrictions": null` or it returns HTTP 422.
- A green PR can still report `BEHIND` under strict checks → refresh with the `update-branch` endpoint, then **wait for the re-run** before merging.
- Anything that adds a required status-check context must itself land via PR, and the protection body must then be re-applied with the new context appended.
- Commits must be GPG-signed (`git commit -S`, key `609F7926A8254CDB`); merge is squash-only with branch deletion; `--auto` merge stays disabled.

---

## File Structure

| Path | Responsibility | Action |
|---|---|---|
| `scripts/org-delivery-audit.sh` | Org-wide read-only state capture: protection, required contexts, main CI, open PRs | Create |
| `ansible/roles/wireguard/molecule/default/verify.yml` | WireGuard molecule assertions | Modify (truncate repair) |
| `ansible/roles/vault/molecule/default/verify.yml` | Vault molecule assertion | Modify (quoting repair) |
| `.github/workflows/ci.yml` | Required `ci` gate | Modify (add ansible YAML parse) |
| `.gitleaksignore` (per repo) | Documented false-positive ledger | Review |
| `DEPLOYMENT_GATE.md`, `security/key-custody.md`, `CHANGELOG.md` | Deviation register + evidence | Modify |
| `audits/internal/2026-09-delivery-chain/REPORT.md` | This audit's evidence record | Create |

---

## Phase 1 — Capture (read-only, no changes)

### Task 1: Org-wide state capture script

**Files:**
- Create: `scripts/org-delivery-audit.sh`

Steps: confirm `gh` auth and org membership; create the read-only capture script; run it to a TSV baseline; copy the baseline into `audits/internal/2026-09-delivery-chain/baseline.tsv`.

Expected columns per repo: visibility, default branch, squash-only, auto-merge, required_signatures, strict, linear history, conversation resolution, code-owner reviews, admin enforcement, required review count, required contexts, open PR count, failed runs on `main`, newest `main` run conclusion.

Verified expectations from the prior hardening audit: `def_branch=main`, squash-only yes, auto-merge no, signatures yes, strict yes, linear yes, conversation-resolution yes, code-owner yes, admin-enforced yes, required reviews 0.

Any mismatch with expectations **is a finding** — record it, do not silently fix.

### Task 2: Reconcile local clones with origin

Detect uncommitted/unpushed work in every clone; fast-forward only (never merge/rebase `main`); verify every `.git/hooks/pre-commit` `INSTALL_PYTHON` points at `/opt/jolarca/repos/jolarca-infrastructure/.venv/bin/python` (a stale `/opt/jol-m/...` path silently disables the local gate).

Known risk: `jolarca-infrastructure` may carry an uncommitted pre-commit trailing-whitespace auto-fix in `scripts/terraform-state-rename-jolarca.sh`.

---

## Phase 2 — Remediate code defects that reached `main`

### Task 3: Repair the truncated WireGuard molecule verify file

`ansible/roles/wireguard/molecule/default/verify.yml:18` ends mid-token (`failed_when: "=) — unparseable YAML sitting on `main`. Prove the parse failure, complete the file to assert package presence, `net.ipv4.ip_forward = 1`, `wg --version`, and `/etc/wireguard` existence (matching `roles/wireguard/tasks/main.yml:10-18`), then verify parse + lint clean, commit signed, push.

### Task 4: Repair the always-failing Vault molecule assertion

`ansible/roles/vault/molecule/default/verify.yml:10` reads `failed_when: "Vault not in vault_ver.stdout"` — one literal string, always truthy, so the check can never pass. Fix to `failed_when: "'Vault' not in vault_ver.stdout"` and prove the parsed value is now a Jinja expression.

### Task 5: Close the CI gap that let unparseable YAML reach `main`

`ci.yml` lints only `.github/ backup/ monitoring/ .pre-commit-config.yaml qodana.yaml`; `ansible.yml` syntax-checks only `playbooks/*.yml`. No required check parses `ansible/roles/**`. Add a parse-only (not style) gate for the whole ansible tree to the required `ci` job, run the equivalent check locally, open the PR, watch checks, squash-merge.

---

## Phase 3 — Dependency and PR backlog

### Task 6: Land the three open `jolarca-infrastructure` PRs in the right order

Inspect each diff first. Merge #23 (staging `hashicorp/google` 6.50→8.1.0) first, requiring `plan` to show **no resource changes** as a hard stop. Then land #21 and #22 (paired `bpg/proxmox` production + staging) together so environments stay on the same provider major. Finish with zero open PRs.

### Task 7: Triage the 20 open `jolarca` Dependabot PRs

Classify patch/minor vs major. Majors needing explicit review: #74 django 5.2.17→6.1.1, #88 eslint 9→10, #83 zod 3→4, #80 isomorphic-dompurify 3→4, #75 @types/node 22→26, #90 react, #76 virtualenv. Merge patch/minor oldest-first on green, refreshing `BEHIND` via the `update-branch` API. Apply the two verified frontend failure patterns before blaming a PR: peer-coupling (the `vitest` ↔ `@vitest/coverage-v8` precedent — coupled PRs must land as one) and stale `package-lock.json` (`Missing <pkg> from lock file`). The Django major is an explicit merge-or-defer decision with the reason recorded; silent staleness is the finding.

---

## Phase 4 — Security controls

### Task 8: Secret-scanning CI parity and ignore-ledger review

Assert a `security` workflow exists in all six repos; review every `.gitleaksignore` fingerprint for written justification (unjustified entry = real finding); confirm the nightly schedule trigger actually exists; run `scripts/audit-no-secrets.sh` and a full-history gitleaks scan locally.

### Task 9: Supply-chain hygiene — pinned Actions across repos

Find every `uses:` reference without a `# vX.Y.Z` comment and every mutable-tag action; verify workflow-level `permissions:` declarations and org Actions permissions. Remediate to `owner/repo@<sha> # vX.Y.Z` (this repo's convention) via PR.

### Task 10: Deviation register reconciliation

Confirm the three tracked deviations are each documented with an owner and re-review date: `required_approving_review_count: 0`, CodeQL disabled outside `jolarca`, and public visibility of all six repos. For CodeQL, enable-or-restate rather than drift, and name the compensating controls. Verify public visibility exposes no secret material (`secrets/encrypted/` README-only, no tracked `*.tfstate|*.tfvars|*.pem|*.key|*.p12`).

---

## Phase 5 — Local gate integrity

### Task 11: Fix toolchain gaps that make the local gate weaker than CI

Install the missing `checkov` into the shared pre-commit venv; re-run `pre-commit run --all-files` and separate new failures from pre-existing ansible-lint debt; compare local pinned ansible-lint against CI's unpinned `pipx install ansible-lint` and pin CI to match; confirm the `ansible` workflow's `wireguard`/`vault` molecule legs have ever executed on `main` (if not, record a gate-integrity finding).

---

## Phase 6 — Final verification

### Task 12: End-to-end re-verification of the chain

Re-run the org capture and diff against baseline; confirm every repo's `main` is green and every clone in sync; confirm no stray branches from merged PRs remain; write `audits/internal/2026-09-delivery-chain/REPORT.md`; update `CHANGELOG.md` and `DEPLOYMENT_GATE.md`. The gate verdict may only move from `CONDITIONAL PASS` to `PASS` if Tasks 3–6 merged **and** the final sweep is fully green **and** no new finding is left undocumented — otherwise it stays `CONDITIONAL PASS` with the residual list named.

---

## Self-Review Notes

- **Coverage:** branch/commit/push (Tasks 2–5), PR (5, 6, 7, 12), CI (5, 11), merge→main (5, 6, 7, 12), security (8, 9, 10), verification (1, 12).
- **Deliberate non-goals:** no production `terraform apply`, no Proxmox/staging provisioning, no protection tightening beyond restoring drift — staging remains unprovisioned by design.
- **Highest-risk steps:** Task 6 Step 2 (Terraform `plan` must show no resource changes) and Task 7 Step 4 (Django major touching the payment boundary). Both are hard stops.

## Known deviation from the original draft

The initially drafted `org-delivery-audit.sh` contained a malformed jq pipeline (a stray `jq ... /dev/null` no-op and duplicated TSV emission). The implemented script in `scripts/org-delivery-audit.sh` is the corrected single-pass version producing the same columns.
