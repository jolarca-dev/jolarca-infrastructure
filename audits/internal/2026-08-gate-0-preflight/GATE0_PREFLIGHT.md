# GATE 0 — State Migration Pre-Flight Report (CHG-2026-08)

- **Date:** 2026-08-15 (UTC) · **Change record:** [jol-m-compliance#3](https://github.com/journeyoflife-org/jol-m-compliance/issues/3)
- **Doctrine:** ADR-0003 (accepted), `docs/runbooks/bootstrap-state-backend.md`, `STEP0_VERIFICATION.md`
- **Scope discipline:** verification + documentation only. **Zero terraform mutations performed; zero secrets printed.**

---

## 1. Baseline verification — PASS

| Check | Evidence | Result |
|---|---|---|
| STEP 0 merged | `0086905` ancestor of origin/main | ✅ |
| ADR-0004 separation merged | `4ed01f2` = origin/main HEAD | ✅ |
| CI green on main | ci / security / compliance-check / terraform / fleet-separation-guard all `success` @ `4ed01f2` | ✅ |
| Version skew (noted, non-blocking) | local terraform v1.15.8 vs CI pin 1.9.8 (.github/actions/terraform-setup). State format v4 stable across 1.x; migration runs locally, CI reads after phase B. | ⚠ recorded |

## 2. Safety floor — PASS (1 documented pre-existing deviation)

| Check | Command | Result |
|---|---|---|
| Secrets in history | `gitleaks detect --source . --no-banner --redact` | `no leaks found` |
| gitignore coverage | `grep` on `.gitignore` | `*.tfstate`(×2), `*.tfplan`, `**/.terraform/*`(×2), `*.pem`, `*.key` all present |
| State credential scan | pattern scan (PAT/AWS/PEM/Slack/AGE/token-fields), counts only | 2/2 files **CLEAN** |
| Pre-commit | hook installed; `pre-commit run --all-files` | all hooks Passed **except** ↓ |
| Deviation | **CKV_GHA_7** on `.github/workflows/terraform.yml:21-27` (workflow_dispatch `environment` input). Pre-existing (predates STEP 0), intentional: that input IS the human gate for applies. CI checkov scope (terraform/ dirs only) never saw it. Follow-up: documented skip or CI-scope decision — NOT mutated in GATE 0. | ⚠ recorded |

## 3. State inventory (A2/A4 migration targets; shred after verification)

| File | Size | sha256 | Credential scan |
|---|---|---|---|
| `terraform/environments/production/terraform.tfstate` | 5094 B | `e1c45a53457a11d83233d74586ebbff14da27e14a03e18b4d09a17eaf2392c22` | CLEAN |
| `terraform/environments/production/terraform.tfstate.backup` | 4411 B | `a9b29508fe49a713b22276a2c3645abc34bca59cd623ce5cf31b94cdfa2bf369` | CLEAN |
| `terraform/bootstrap/terraform.tfstate.d/` | empty dir | — | — |

## 4. Pre-migration backup (rollback artifact) — DONE

- Location: `/home/jol/state-backups/20260815T204228Z/` (mode 700/600, outside all git repos)
- **Deviation:** requested path `/opt/jol-m/state-backups` is not writable by the operator account (`/opt/jol-m` is root-owned). Relocated to `$HOME/state-backups`; custody intent preserved and recorded in CHG-2026-08.
- Contents: both state files + `SHA256SUMS` + `MANIFEST`. Retention: shred after phase-B merge + 7-day soak.

## 5. Separation covenant (ADR-0004) — PASS

- `fleet-separation-guard` green on main @ `4ed01f2`; local guard run: `FLEET SEPARATION OK: org jol-m-* set == terraform fleet map (5 repos)`.
- `jol-c-*` references: **0**.
- Mission-repo references in code/config: 2 hits, both benign provenance comments (`qodana.yaml` template inheritance; `modules/github-org/versions.tf` pin origin). No access artifacts (tokens/workflows/CODEOWNERS/module deps) cross the boundary.

## 6. Prompt-review notes (professional additions applied)

1. Scanned both `jol-c-*` (as written) and the actual mission prefix `jol-*` — the covenant uses the latter.
2. Backup relocation documented (permission finding at `/opt/jol-m` — worth a follow-up on directory ownership).
3. CKV_GHA_7 surfaced by the full-repo hook run — recorded as deviation, not silently skipped, not mutated in a no-mutation gate.
4. Version skew (1.15.8 local vs 1.9.8 CI pin) recorded — non-blocking for format v4, revisit if state format ever bumps.
5. Added backup retention/shred rule to the manifest (backups are crown jewels too).

---

## Verdict

**READY FOR A1 — pending operator input:**

1. **Staging GCP project ID** (`TF_VAR_project_id`, runtime-only — never committed), and
2. **Change-window confirmation** (change record CHG-2026-08 sign-off line).

No state moves before both are provided and the A1 plan is printed and confirmed.
