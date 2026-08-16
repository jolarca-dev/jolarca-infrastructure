# EXECUTION BUNDLE 18–21 — Payment boundary remediation (evidence, no verdict)

Produced by the executing engineer. The PROVEN/NOT-PROVEN judgment
belongs to the independent re-audit (Step 22b). Stripe TEST mode
throughout; zero real keys committed; zero PAN fields in any surface.

## Strict order honored

18 (hub purge) → 19 (guards armed) → 20 (boundary live) → 21 (E3 + N2).
Each step's acceptance criteria were met and merged before the next
started: #76 → #77/#81 → #18 → #82/this PR.

## STEP 18 — purge residue + arm protection prep (B1)

- Repo: jol-hub · PR #76 · merge commit `89c4812d`
- PB-01…PB-06 purged (diff in PR); EXTRA: unauthenticated
  StripeWebhookView surface removed; SDK uninstalled from local venvs.
- Sentry tests inverted (PB-05) + `data/tests/test_dependency_guard.py`
  added: 3/3 green locally, re-run green in CI (Dependency Guard job).
- Evidence file: `jol-hub/STEP18_EXECUTED.md` (committed).
- Pre-merge CI: hub legacy jobs red PRE-EXISTING (broken Django pin etc.,
  OBS-18-3); guard-related checks green; protection had no required
  contexts at the time (N1), so merge was not check-gated — arming
  sequenced to STEP 19 to avoid chicken-and-egg (documented).

## STEP 19 — E1/E2 required checks + bypass closure (B2, N1)

- Repo: jol-hub · guards PR #77 merged `85d51489`; arming+evidence PR #81
- Vendored guard byte-identical to the infra record copy, sha256-pinned:
  `8fa2dd12f12320dff268ee19d5b00422a1f5987203e34755c342e56068ed47a5`
- Protection ARMED (API-verified): contexts
  `Payment Boundary Guard (E1, ADR-0005)` + `Dependency Guard (E2,
  ADR-0005)`, strict, `enforce_admins: true`, review count 0 (solo-era).
- Incident OBS-19-1 (opened+closed in-step): pre-hardening admin bypass
  merged probe PR #78; reverted (#79, `ba2f7c63`); bypass closed; re-test
  PR #80 — violation blocked on BOTH normal and `--admin` merge paths
  ("Repository rule violations found — Required status check … failing").
- Positive: guard jobs green on clean PRs (#77, #81, #82).
- Evidence file: `jol-hub/STEP19_EXECUTED.md` (committed).

## STEP 20 — /internal/v1 live locally + contract green (B3, C4, C5, RSK-010)

- Repo: jol-m-marketplace · PR #18 · merge commit `4faef0a3`
- Endpoints: POST/GET payment-intents, POST refunds — HMAC auth (60 s
  TTL), caller↔product binding, idempotency (replay/409), scoped 404,
  whitelist PAN-free serialization, 503 degraded mode.
- C4: forged Stripe webhook → 400 (regression test included).
- C5: product attribution in InternalPaymentIntent/InternalRefund +
  PaymentRecord (migration 0002).
- RSK-010: boundary-side refund endpoint moves ledger state (hub-side
  client wiring = donation-flow workstream).
- Contract suite: 14/14 + unit + security = 48/48 green vs the LIVE
  local compose stack (Postgres/Redis); live HTTP demo recorded.
- Honest deviation noted in the evidence file: suite+implementation
  landed in one commit; first run caught 9 implementation defects.
- Evidence file: `jol-m-marketplace/STEP20_EXECUTED.md` (committed).
- Observation OBS-20-1: marketplace CI gitleaks/docker-scan jobs red on
  the PR (non-required checks); local pre-commit gitleaks clean with
  documented `gitleaks:allow` test-key tags. Follow-up: marketplace CI
  hygiene.

## STEP 21 — E3 staging + N2 + credential-independent deny (B4 staging, N2)

- Repo: jol-m-infrastructure (+ jol-hub N2 PR #82 merged `4f93c6b9`)
- N2 FIRST: hub→payment-API egress row, fail-closed via
  `paymentsApi.cidr` (helm) / documented substitute (kustomize). The E1
  guard flagged this PR's own prose (endpoint literal) before reword —
  guard caught its authors.
- E3 staging plane: `scripts/e3-network-deny-test.sh` (record copy).
  Results (reproduced): NEGATIVE PASS (hub WITH valid test key →
  `BLOCKED BY NETWORK: gaierror` — denied below the auth layer);
  POSITIVE PASS ×2 (hub→payment-API; boundary→Stripe). js.stripe.com
  browser carve-out intact by design.
- Drift alerting declared in `security/network-policy.md` (matrix status
  column + drift section).
- STAGING ONLY; production human-gated; GKE rows deploy with the cluster
  workstream (declared, honest boundary).
- Evidence file: `STEP21_EXECUTED.md` (this repo, committed).

## Fleet-wide invariants (spot-checkable now)

- `grep -rIn --include='*.py' -E '^\s*(import stripe|from stripe)'
  /opt/jol/repos/jol-hub/backend/django` → 0 hits.
- Fleet entropy scan (`sk_/rk_/whsec_` ≥20 chars) across hub +
  marketplace + infra → 0 hits.
- Hub branch protection: two boundary guards REQUIRED, enforce_admins
  true; violation merges impossible (proven by PR #80).
- `git log` in all three repos shows the remediation commits: the thing
  three audits found missing.

## Open items handed to the re-audit / follow-up workstreams

1. Hub legacy CI baseline repair (OBS-18-3) → then broaden required set.
2. Marketplace CI hygiene (OBS-20-1).
3. GKE deployment of the E3 rows + mTLS transport layer (STEP 21
   staging-plane proofs stand in until then).
4. Hub donation-flow client wiring against /internal/v1 (B3 consumer
   side) + recurring-donation contract amendment.
5. Donation VAT/receipt routing confirmation with jol-m-legal + tax
   advisor (B8).
6. Compliance repo updates (scope statement PROVEN-conditional wording,
   risk closures) are the RE-AUDIT's loop-closure inputs — executor does
   not self-attest.

**Steps 18–21 executed and committed. Ready for independent re-audit
(Step 22b).**
