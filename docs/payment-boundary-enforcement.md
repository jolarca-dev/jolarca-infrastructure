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
| `Backend - Unit & Integration Tests` | ci.yml | STEP 19 |
| `payment-boundary-guard` | ci.yml (STEP 19) | STEP 19 |
| `dependency-guard` | ci.yml (STEP 19) | STEP 19 |

Application evidence (date, API call, resulting protection state) is
recorded in the STEP 19 execution file in jol-hub, not here.

## Status ledger

| Date | Event |
|------|-------|
| 2026-08-17 | ADR-0005 + contract codified (STEP 10 artifacts committed) |
| 2026-08-17 | STEP 17 audit: NOT PROVEN (findings PB-01…PB-06) |
| 2026-08-17 | STEP 22/22B re-audits: premise failed, blockers B1–B8 |
| 2026-08-17 | STEP 18: hub residue purged (jol-hub PR #76); E1 record copy upgraded (layered scan, named exemptions) |
