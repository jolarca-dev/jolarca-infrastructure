# Payment boundary enforcement registry (Model A, ADR-0005)

Single source of truth for the structural controls that keep jol-hub out
of PCI scope. Complements ADR-0005, `docs/payment-api-contract.md`, and
`security/network-policy.md` (§ payment boundary).

## Controls

| # | Control | Artifact | Custody |
|---|---------|----------|---------|
| E1 | CI grep guard (Stripe SDK/keys/server endpoints) | `scripts/check-payment-boundary.sh` (RECORD COPY; vendored into jol-hub CI) | this repo = record; hub CI = enforcement |
| E2 | Dependency allow-list guard | `jol-hub/data/tests/test_dependency_guard.py` (fails on installed or declared `stripe`) | hub |
| E3 | Network egress denial (hub → api.stripe.com) | `security/network-policy.md` matrix; hub NetworkPolicy manifests (default-deny, no external-443 rows) | this repo (doctrine) + hub infra (manifests) |

## Record-copy / vendoring contract (E1)

- The record copy lives at `scripts/check-payment-boundary.sh` in THIS
  repo; jol-hub vendors a copy for its CI.
- Drift check: hub CI compares its vendored copy against this record
  copy (fetched from jol-m-infrastructure main) and FAILS on divergence
  unless the divergence is landed in BOTH repos in the same change
  window. The guard's exemption list (venv noise, sentry-test fixtures,
  ledger vocabulary) is part of the contract — extending it requires an
  ADR amending ADR-0005.

## jol-hub required status checks (N1 fix)

Hub branch protection required checks are applied operationally (gh API)
because hub is MISSION custody — ADR-0004 R1/R3/R4 forbid this repo's
`github-org` Terraform module from managing a mission repo. Applied set
(job names must match hub CI exactly):

| Context | Source workflow | Added |
|---------|-----------------|-------|
| `Payment Boundary Guard (E1, ADR-0005)` | payment-boundary-guard.yml | STEP 19 — ARMED |
| `Dependency Guard (E2, ADR-0005)` | payment-boundary-guard.yml | STEP 19 — ARMED |

Applied 2026-08-17 via gh API (PATCH contexts; POST enforce_admins):
`strict: true`, both contexts required, `enforce_admins: true` (admin
bypass CLOSED), review count 0 (solo-era, marketplace precedent).
Pre-existing red hub jobs (broken Django pin / frontend lint debt,
OBS-18-3) are deliberately NOT required — broadening follows hub CI
baseline repair. Evidence: STEP19_EXECUTED.md (jol-hub), incl. the
blocked violation PR #80 on BOTH normal and admin merge paths.
Application note: hub protection writes require PATCH/POST sub-resource
calls with this token (PUT on the collection returns 404).

## Status ledger

| Date | Event |
|------|-------|
| 2026-08-17 | ADR-0005 + contract codified (STEP 10 artifacts committed) |
| 2026-08-17 | STEP 17 audit: NOT PROVEN (findings PB-01…PB-06) |
| 2026-08-17 | STEP 22/22B re-audits: premise failed, blockers B1–B8 |
| 2026-08-17 | STEP 18: hub residue purged (jol-hub PR #76, merged `89c4812d`); E1 record copy upgraded (layered scan, named exemptions) |
| 2026-08-17 | STEP 19: E1/E2 wired as REQUIRED checks + enforce_admins=true; violation PR #80 blocked on both merge paths (jol-hub guards PR #77 merged `85d51489`; arming+evidence PR #81) |
| 2026-08-17 | STEP 20: /internal/v1 live locally; contract suite 14/14 + 48/48 green; C4/C5/RSK-010 fixed (marketplace `4faef0a3`) |
| 2026-08-17 | STEP 21: N2 row landed fail-closed (jol-hub `4f93c6b9`); E3 staging plane deployed + credential-independent deny proven (`scripts/e3-network-deny-test.sh`); drift alerting declared |
| 2026-08-17 | STEP 22C independent re-audit: premise PASSED; every control reproduced (fresh negative test jol-hub PR #83 blocked on normal AND admin paths; E3 re-run green; contract suite 14/14 live); scope statement upgraded CONDITIONAL → PROVEN; G3 CONDITIONAL CLEARANCE (boundary cleared, first donation withheld on DPIA-003 / VIES / Stripe TIA+AoC / RSK-013 / RSK-014). Canonical report: `STEP22C_FINAL_REAUDIT.md`; sealed evidence: jol-m-compliance `audits/gate-evidence/G3-payments/` |
