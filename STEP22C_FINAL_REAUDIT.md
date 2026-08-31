# STEP 22C — FINAL INDEPENDENT RE-AUDIT: Model A Payment Boundary

- **Date:** 2026-08-17
- **Persona:** independent auditor — paranoid, evidence-first, hostile to
  self-attestation. Zero inherited claims: every control below was
  reproduced in this session.
- **Scope:** verify the execution's claim that Steps 18–21 are done; then
  prove or disprove that jol-hub is out of PCI scope; then close G3 or
  name what remains.
- **Prior audits:** STEP 17 (NOT PROVEN — residue), STEP 22 (NOT PROVEN —
  premise failed), STEP 22B (NOT PROVEN — premise failed, stopped at gate).

---

## STEP 0 — PREMISE CHECK: **PASSED**

| Claim | Verification (this session) | Result |
|---|---|---|
| Step 18 merged | `git log` jol-hub: `89c4812d … (#76)` | present |
| Step 19 merged | `85d51489 (#77)`, `07eed1ce (#81)`, revert pair `ba2f7c63 (#79)` / `b9b3d0a0 (#78)` | present |
| Step 20 merged | `git log` jolarca origin/main: `4faef0a3 … (#18)` | present |
| Step 21 merged | jol-hub `4f93c6b9 (#82)`; jolarca-infrastructure `90d589a (#10)` | present |
| STEP18/19_EXECUTED.md committed | `git ls-files --error-unmatch` in jol-hub | COMMITTED |
| STEP20_EXECUTED.md committed | `git ls-tree origin/main` in jolarca | COMMITTED |
| STEP21_EXECUTED.md + EXECUTION_BUNDLE_18-21.md committed | `git ls-files` in jolarca-infrastructure | COMMITTED |

One sync anomaly found and resolved: the local marketplace checkout was
one commit behind origin/main (`67d91cd`); `STEP20_EXECUTED.md` WAS
committed on origin/main (`4faef0a3`). Premise failure avoided by
checking the remote, not just the local worktree. N3 lesson applied.

Residual premise defect (recorded, not premise-breaking): the STEP 17/22
audit artifacts in **jolarca-compliance** were still untracked working-tree
files. This re-audit commits them (see loop closure).

---

## PER-CONTROL VERDICTS

### C1-code — **PROVEN** (reproduced)

- PB-01…PB-06 re-grepped at the corrected original locations
  (`backend/requirements.txt`, `backend/django/requirements.txt`,
  `backend/django/core/settings/base.py`, `backend/django/apps/core/{secrets,vault}.py`,
  `infra/terraform/{variables,main,outputs}.tf`,
  `infra/kubernetes/base/secrets.yaml`, `infra/kubernetes/security/security.yaml`,
  `infra/helm/jol-hub/templates/secrets.yaml`, `backend/django/.env.example`,
  `countries/lt/config/payment-providers.yml`): **all clean**. Only
  surviving mention is documentary prose in `secrets.py` ("get_stripe_keys()
  was purged") — acceptable.
- Fleet entropy scan (`sk_live/sk_test/rk_live/whsec_` shapes) across all
  three repos: **0 real-looking keys**.
- Server-side Stripe imports fleet-wide: **only** marketplace
  `payments_app/{urls,__init__,webhooks,services}.py`. Boundary ownership
  holds in code.
- Inverted sentries present and green (my run, hub django venv):
  `test_pci_secrets_isolation` + `test_model_a_no_stripe_import_in_backend`
  → **2 passed**; E2 `test_dependency_guard.py` → **3 passed**.
- Hub environment: `import stripe` impossible (spec not found); no SDK
  installed.
- NOTE (auditor correction): hub's Django tree nests under
  `backend/django/`; earlier audit greps at root paths were path errors,
  not control failures. The purge itself (PR #76 diff, GitHub-side) was
  real.

### C1-CI guard (E1/E2) — **PROVEN** (reproduced, incl. fresh negative test)

- Live protection API: required checks =
  `["Payment Boundary Guard (E1, ADR-0005)", "Dependency Guard (E2, ADR-0005)"]`,
  `strict: true`, `enforce_admins: true`.
- Vendored guard sha256 == upstream record:
  `8fa2dd12f12320dff268ee19d5b00422a1f5987203e34755c342e56068ed47a5` (both).
- Workflow has NO path filter (runs on every PR).
- **Negative test (mine, this session):** branch
  `audit/step22c-negative-test`, file with `import stripe` + fake
  `sk_test_` key → PR jol-hub **#83**:
  - E1 check: **FAILURE** (also local reproduce: exit 1, both patterns hit).
  - Merge attempt, normal path: *"base branch policy prohibits the merge"*.
  - Merge attempt, admin path (REST `PUT /pulls/83/merge`, admin token):
    **HTTP 405 — "Repository rule violations found — Required status check
    'Payment Boundary Guard (E1, ADR-0005)' is failing"**.
  - PR closed unmerged; remote branch deleted; jol-hub main SHA unchanged
    (`4f93c6b9`).
- An audit-relevant repo fact surfaced: an active ruleset (`~master`)
  also constrains merge methods; the admin-path test had to be re-run
  with an allowed method to reach the check evaluation — it was, and the
  block held.

### C1-network / E3 — **PROVEN at mechanism level** (reproduced; GKE deferral ruled below)

My own run of `scripts/e3-network-deny-test.sh`:

```
NEGATIVE PASS: hub egress denied at network layer
POSITIVE PASS: sanctioned flow works
POSITIVE PASS: boundary->Stripe works
E3 NETWORK DENY: ALL CHECKS PASSED
```

N2 fail-closed hub→payment-API egress row: present in
`infra/helm/jol-hub/templates/networkpolicy.yaml`, renders only when
`paymentsApi.cidr` is set (empty default = row absent = fail-closed),
merged via hub PR #82 (`4f93c6b9`).

**Auditor ruling on mechanism-level sufficiency:** SUFFICIENT for the
current PCI-scope claim, because (a) no production hub deployment exists
anywhere — there is no plane where denial could be weaker than proven;
(b) the deployment shape (helm row + policy manifests) is fail-closed by
construction; (c) the staging-plane proof is credential-independent.
GKE/k8s production deployment of the rows is a **precondition of hub
production go-live, not of G3**, and is tracked as **RSK-012** (owner:
Infra).

### C2 SAQ-A + hostile attempt — **PROVEN** (caveat from 17/22 CLOSED)

Hostile hub→Stripe attempt repeated with a **valid** Stripe test key in
the hub plane: denied at the **network layer** (`gaierror` — egress cut
below the auth layer). This is topology, not credential absence. Hub
holds no Stripe secret (entropy scan, settings purge, SDK absence —
C1-code). The STEP 17/22 caveat ("blocked only for lack of credentials")
is closed.

### C3 contract regression — **PROVEN** (my own run, live topology)

`docker compose -f docker-compose.test.yml` (Postgres/PostGIS + Redis +
backend, test settings), then `pytest tests/contract -v` — **14/14
PASSED** in this session:

- unknown caller 401 · forged signature 401 · expired timestamp 401
- caller↔product binding 403
- create intent 201 + PAN-free schema walk
- missing Idempotency-Key 400 · replay → same intent · key+diff → 409
- scoped GET → 404 (no enumeration oracle)
- refund gate 422 · refund idempotent
- degraded mode 503 typed + retryable
- webhook forgery → 400 · valid webhook dedup + signed X-Product forwarding

Not the execution's 48/48 claim — my own 14/14 against the live stack.

### C4 webhook — **PROVEN**

Forgery → 400 (the C4 defect is fixed; regression test present and green
in my run). Dedup holds (same event_id replayed → single record).
Per-product forwarding signed (`X-Product` + HMAC over `ts.sha256(body)`)
and verified end-to-end in the suite.

### C5 revenue attribution — **PROVEN**

Migration `0002_internal_payment_api.py` present: `product` field on the
internal intent/refund ledgers AND retrofitted onto `PaymentRecord`
(default `marketplace`), with `payments_pr_product_idx`. Scoped-GET
proves hub-donation vs marketplace-order separability (foreign product →
404). Finance-mart consumption: not independently verified (no mart in
repo) — recorded as out-of-audit-scope note, not a control failure.

### C6 degraded mode — **PROVEN** (app layer)

Live drill via suite: outage flag → typed 503 `retryable: true` on every
internal endpoint (enforced in shared dispatch). Bypass-path analysis:
hub has no Stripe SDK, no keys, no webhook endpoint, and network egress
denial in the staging plane; re-introducing a PSP client requires a
merge that E1/E2 block. **No bypass path exists.** (The mTLS transport
layer remains contract-declared but not deployed — same deferral class
as RSK-012.)

### RSK-010 — **PARTIAL: routing PROVEN, money movement RESIDUAL (RSK-014)**

Refunds are routable ONLY through the boundary: 422 gating
(reason mandatory, refundable-status gate, over-refund prevention),
partial-refund accounting, idempotent replay — all reproduced. **But:**
`RefundCreateView` does not import or call `services.refund`
(`stripe.Refund.create`); it updates the internal ledger only. The
execution's phrasing "real money moves via the boundary" is not yet true
in code — no live PSP exists anywhere to move money against. The
PCI-relevant property (refund capability exists only inside the
boundary) holds; the money-movement wiring is **RSK-014**, owner
Marketplace, due at live PSP wiring.

---

## NEW FINDINGS (this re-audit)

1. **RSK-013 (HIGH, new): the boundary repo is unguarded.** jolarca
   main has `required_status_checks: null`, and its CI does not run
   `tests/contract` at all (compose default command targets
   `tests/integration`, which contains only `__init__.py` → pytest exit 5
   if it ever reached it; it currently dies earlier at GDAL install).
   Marketplace CI was red on the parent commit too (pre-existing rot —
   PR #18 touched no workflows), but the contract guarantee that
   protects SAQ-A is enforced by ad-hoc runs (like this one) only.
   Owner: Marketplace. Due: before first live donation.
2. **RSK-014 (new):** refund PSP-execution gap, as above.
3. **OBS-22C-1 (WATCH):** PayPal-era residue in hub — unused
   `get_paypal_credentials()` vault reader + `METHOD_PAYPAL` enum label;
   zero callers, zero live client. Not a scope violation today; any
   future PSP must enter via the boundary.
4. **OBS-22C-2:** hub compliance suite carries one pre-existing red test
   (`test_secrets_module_exists` — expects
   `infra/terraform/modules/secrets`, which never existed in history).
   Legacy debt (OBS-18-3), not a STEP-18 regression.

---

## ADJUDICATION OF THE EXECUTION'S FOUR CAVEATS

| # | Caveat | Ruling | Basis |
|---|---|---|---|
| 1 | OBS-19-1 admin bypass incident | **ACCEPTABLE — closed** | Re-tested this session with my own violation PR: blocked on BOTH paths; admin REST path returned HTTP 405 naming the failing required check. `enforce_admins: true` confirmed live. |
| 2 | Tests-first deviation (suite+impl one commit) | **ACCEPTABLE for G3** | The guarantee at issue is the property, not the development ritual: the suite exists, is green live (my run), and covers every contract clause. Strict fail-first ordering is a process nicety; its absence does not weaken a guarantee that is independently reproducible. Condition: wire the suite into CI (RSK-013) so it stops being ad-hoc. |
| 3 | Staging-plane-only E3 (no GKE) | **MECHANISM PROOF CLEARS G3; cluster deployment DEFERRED as RSK-012 (owner Infra)** | No production hub plane exists, so the proven staging-plane mechanism is the tightest available truth; the helm/k8s shape is fail-closed. Deferral is explicit, owned, and gates hub production go-live. |
| 4 | OBS-18-3 / OBS-20-1 legacy CI | **OBS-18-3: acceptable residual** (owner hub team; non-required, non-PCI checks). **OBS-20-1: escalated to RSK-013** — marketplace's ungated main IS PCI-relevant because the boundary lives there. | See findings 1 and 4. |

---

## LOOP CLOSURE (performed by this re-audit, in jolarca-compliance)

1. **PCI scope statement** → upgraded CONDITIONAL → **PROVEN**
   (`certifications/pci-dss/scope-statement-model-a.md`), evidence-linked.
2. **Risk register** → RSK-006/007/008/009/010 CLOSED with evidence;
   N1/N2/N3 CLOSED; PB-01…06 CLOSED under RSK-006; OBS-19-1 acceptable;
   OBS-18-3/OBS-20-1 residual-with-owner; RSK-011 remains OPEN (VAT/
   receipts); new RSK-012/013/014 registered.
3. **Archive** → all step reports + this re-audit copied hash-pinned
   into `audits/gate-evidence/G3-payments/reports/` with
   `evidence-manifest.md`; prior-art hashes re-verified unchanged
   (STEP 17: `86f028d2…`, STEP 22: `91fa1a75…`). The previously
   untracked STEP 17/22 audit artifacts are committed by this bundle.

## G3 DECISION — **CONDITIONAL CLEARANCE** (boundary CLEARED; first donation WITHHELD)

G3 checklist (`audits/gate-evidence/G3-payments/README.md`):

- [x] SAQ-A scope validation — **PROVEN** (C1/C2, this re-audit)
- [x] Replay-attack test results — **PROVEN** (idempotent replay, 409
      conflict, expired-timestamp 401, forged-webhook 400; reproduced)
- [ ] VAT reconciliation evidence (VIES) — **OPEN** (no evidence exists;
      RSK-011)
- [ ] DPIA 003 signed + hash — **OPEN** (`dpia/003-payments-and-vat` is
      a draft skeleton)
- [ ] Stripe TIA + AoC link in vendor register — **OPEN**
      (`vendor-assessments/stripe`: "onboarding — artifacts pending")

**Decision:** the Model A payment boundary is CLEARED at G3 — the
previously-unchecked payment controls (scope + replay) now pass with
reproduced evidence. The full gate for the **first real donation**
remains WITHHELD on three compliance workstream items (DPIA-003
signature, VIES VAT evidence, Stripe TIA + AoC) and two engineering
preconditions (RSK-013 contract suite as a required check in the
boundary repo; RSK-014 refund PSP wiring). Record:
`audits/gate-evidence/G3-payments/G3_DECISION.md`.

---

## ONE-SENTENCE VERDICT

**Model A is PROVEN — hub is out of PCI scope with every control
independently reproduced — and G3 is CLEARED for the payment boundary,
with first-real-donation authorization withheld pending DPIA-003
signature, VIES VAT evidence, Stripe TIA + AoC, contract-suite CI
gating in the boundary repo (RSK-013), and refund PSP wiring
(RSK-014).**
