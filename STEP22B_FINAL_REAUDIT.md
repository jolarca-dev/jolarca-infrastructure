# STEP 22B — Final Re-Audit: PREMISE FAILED, audit stopped

- **Persona:** independent audit (paranoid, evidence-first)
- **Date:** 2026-08-17
- **Chain:** STEP17_AUDIT.md (`86f028d2…`) → STEP22_REAUDIT.md
  (`91fa1a75…`) → this run
- **Outcome:** the instructed STEP-0 premise check failed; per the audit
  mandate ("if any are missing → STOP, report, do not audit a phantom"),
  no control was certified and nothing was attested.

## STEP 0 — Premise check (reproduced)

| Requirement | Check | Result |
|-------------|-------|--------|
| Steps 18–21 artifacts exist | `ls /opt/jol-m/repos/*/STEP* /opt/jol/repos/jol-hub/STEP*` | **MISSING** — only STEP0/10/17/22 exist anywhere in the fleet |
| Steps 18–21 committed | `git log -8` in jol-hub, jolarca, jolarca-compliance, jolarca-infrastructure | **MISSING** — zero payment-boundary remediation commits; heads are CODEOWNERS/governance (hub), CodeQL fix (marketplace), build-audit hygiene (compliance), CMEK ordering (infra) |
| Live boundary running | `docker ps`, `ss -ltn`, `kubectl` | **MISSING** — marketplace test-db/test-redis only; no application container/listener; `kubectl` → connection refused (no cluster). The :80/:443 listeners are a non-payment edge process; :30000 is the IDE's cef_server — neither is the boundary |

## Spot-check: drift state unchanged since STEP 22

`PB-01` `stripe==14.4.0` still in `backend/django/requirements.txt`;
`PB-02` `STRIPE_SECRET_KEY` plumbing intact (settings 1 hit, secrets.py 4
hits); `PB-05` inverted test still asserts Stripe secrets must exist
(test_compliance.py:929); webhook 500-vs-400 defect intact
(`except ValueError`, webhooks.py); `PaymentRecord.product` still absent
(0 hits). Byte-identical to STEP 22.

## Observations since STEP 22 (non-remediation)

- jol-hub has a large UNCOMMITTED working tree (36 files, SOPS/detect-
  secrets CI hygiene + storage/monitoring infra WIP). None of it is
  payment-boundary remediation, and uncommitted work is not evidence
  regardless.
- N3 remains open: the STEP-17/22 compliance artifacts are STILL
  untracked/uncommitted in jolarca-compliance — no audit evidence in this
  chain is immutable yet. Committing them through the protected branch
  is itself blocker B7.

## What was deliberately NOT done

No control verdicts issued (nothing live to verify against); PCI scope
statement NOT marked PROVEN; RSK-006…RSK-011 NOT closed; G3 NOT
cleared; nothing archived as gate evidence. Attesting any of it now
would be a false certification under PCI-DSS Req. 12.5.2 / SOC 2 CC6.1.

## ONE-SENTENCE VERDICT

**Model A single-payment-boundary remains NOT PROVEN and this audit
STOPPED at the premise gate — Steps 18–21 do not exist in any repo,
committed or otherwise, and no live boundary is running; G3 stays
BLOCKED, the first real donation stays UNAUTHORIZED, and the exact
remaining blockers are unchanged: B1 purge PB-01…PB-06, B2 wire E1/E2
guards + hub branch-protection required checks (N1), B3 implement
`/internal/v1` with product attribution + contract tests, B4 deploy E3
with the payment-API egress row (N2) and re-run the hostile attempt
against topology, B5 fix webhook 400-on-forgery, B6 bring the boundary
up for the live drills, B7 commit the audit evidence (N3), B8 route
donation VAT/receipt to jolarca-legal + tax advisor.**
