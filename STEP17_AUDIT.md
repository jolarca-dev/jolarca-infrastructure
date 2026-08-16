# STEP 17 — Payment Boundary Audit (Model A): Independent Verification

- **Persona:** independent audit (paranoid, evidence-first). Creed: "hub is
  out of PCI scope" is a claim — proven only by reproduced evidence.
- **Date:** 2026-08-17
- **Scope:** fleet-wide Stripe boundary ownership; jol-hub SAQ-A posture;
  contract/webhook/degraded-mode regression; PCI scope statement; residuals.
- **Method:** every verdict below carries the command or file evidence that
  produced it. Nothing is taken from prior step documents without
  re-verification. Repos inspected: `jol-m-marketplace`, `jol-hub`
  (`/opt/jol/repos/`), `jol-m-compliance`, `jol-m-infrastructure`.

## Evidence baseline (what actually exists)

- `jol-m-marketplace/backend/apps/payments_app/` exists (services, webhooks,
  tasks, models) — Stripe SDK usage present.
- `jol-hub` exists at `/opt/jol/repos/jol-hub` with Django backend,
  donations app, frontend donation widgets, and `infra/` (tf/k8s/helm).
- NO deployed runtime anywhere: dev is docker-compose only. No live
  `/internal/v1` endpoint, no cluster, no E3 network control in force.
- `jol-m-compliance`: G3-payments gate evidence checklist is fully
  UNCHECKED (`audits/gate-evidence/G3-payments/README.md`); Steps 13–16
  reports DO NOT EXIST in any fleet repo (verified by file search).

---

## C1 — Boundary ownership (only payments_app touches Stripe)

### (a) Fleet-wide dependency + code scan — PARTIAL PASS

Marketplace containment (Stripe usage outside payments_app):

```bash
grep -rIl -E '\bstripe\b' jol-m-marketplace/backend | grep -v payments_app
# → ONLY dependency manifests (pyproject.toml, requirements/*.txt)
```

Every Stripe CALL site in marketplace is inside `apps/payments_app/`
(`services.py`, `webhooks.py`, `tasks.py`) — verified by file listing +
content read. **Ownership on the marketplace side: PROVEN.**

Hub server code surface:

```bash
grep -rIn --include='*.py' --exclude-dir=venv -E 'import stripe|from stripe|\bstripe\.' \
  jol-hub/backend/django        # → 0 hits
grep -rIn --include='*.py' --exclude-dir=venv 'settings.STRIPE' \
  jol-hub/backend/django        # → 0 consumers of the setting
```

**No hub application code speaks to Stripe. But the audit found dormant
Model-B residue that violates the Model A enforcement contract:**

| # | Finding | Evidence | Class |
|---|---------|----------|-------|
| PB-01 | `stripe` SDK DECLARED in hub deps: `backend/django/requirements.txt:83` (`stripe==14.4.0`), `backend/requirements.txt:49` (`stripe>=14.0`); installed in hub venv (`import stripe` → v14.4.0) | E2 FAIL | HIGH |
| PB-02 | Hub key plumbing: `core/settings/base.py:706` reads `STRIPE_SECRET_KEY`; `apps/core/secrets.py:21,224-227` + `apps/core/vault.py:25` fetch `payments/stripe` from Vault; zero runtime consumers | designed-in violation, dormant | HIGH |
| PB-03 | Hub infra carries the key: `infra/terraform/modules/secrets/main.tf:81`, `infra/kubernetes/base/secrets.yaml:32` (`STRIPE_SECRET_KEY: "sk_live_CHANGE_ME"`), `infra/kubernetes/security/security.yaml:110`, `infra/helm/jol-hub/templates/secrets.yaml:15` | E3/IaC residue | HIGH |
| PB-04 | `countries/lt/config/payment-providers.yml` declares hub's OWN direct Stripe integration incl. webhook subscriptions (`payment_intent.succeeded`, …) | Model-B config residue | MED |
| PB-05 | INVERTED guard: `data/tests/test_compliance.py:929` asserts Stripe secrets MUST be defined in hub — a test that fights Model A | MED |
| PB-06 | `backend/django/.env:39` / `.env.example:32` carry `sk_test_your_stripe_secret_key` placeholder | LOW (placeholder) |

Key-material entropy scan across BOTH repos for real keys
(`sk_(live|test)_[A-Za-z0-9]{20,}`, venv/node_modules excluded):
**0 hits.** All observed values are placeholders. **No second ACTIVE
Stripe touchpoint exists — therefore no CRITICAL-active breach; the
residue is a drift surface, registered as RSK-006.**

### (b) E1 CI guard — FAIL (not wired anywhere)

```bash
grep -nE 'payment|stripe|boundary' jol-hub/.github/workflows/{ci,compliance-check,security-scan}.yml
# → 0 hits
```

`scripts/check-payment-boundary.sh` exists only as the record copy in
`jol-m-infrastructure`; hub CI (now existing) never picked it up. E2's
dependency-guard test likewise absent (no guard test found in hub). The
findings PB-01–PB-06 above are the direct consequence: **without the guard in
CI, residue accumulates silently — exactly what it did.**

### (c) E3 network policy — DECLARED, NOT IN FORCE

`security/network-policy.md` carries the payment-boundary matrix as a
future workstream (its own doctrine: unimplemented rows = acceptance
criteria). No cluster/GKE/NAT allow-list exists yet; hub dev runs via
docker-compose. **Runtime egress denial: UNPROVEN (nothing to enforce).**

**C1 verdict: PARTIAL FAIL.** Ownership holds in source code today
(single consumer = payments_app), but only 1 of 3 structural proofs
(code scan) passes; CI guard and network control are not operational.

---

## C2 — SAQ-A preservation + hostile hub→Stripe attempt — PASS (with caveat)

Hostile test, executed from the hub's own venv (the worst case — the SDK
IS importable there) using the ONLY credential material found in the
entire hub checkout:

```text
$ jol-hub/backend/venv/bin/python
>>> stripe.api_key = "sk_test_your_stripe_secret_key"   # .env:39 placeholder
>>> stripe.PaymentIntent.list(limit=1)
BLOCKED: AuthenticationError: Invalid API Key provided: sk_test_****…
```

Attempt failed for the right reason: **hub holds no valid Stripe
credential** (entropy scan above). Caveat: it failed by credential
absence, NOT by network denial (E3 not in force) — the control that must
make this impossible-by-topology does not exist yet.

Browser-side surface (SAQ-A shape): hub frontend uses ONLY
`@stripe/stripe-js` + `@stripe/react-stripe-js` (Stripe Elements iframe;
`DonationWidget.tsx`, `StripePaymentForm.tsx`); zero `api.stripe.com`
references in hub frontend/backend source (all grep hits were venv
internals). `DonationWidget` obtains `clientSecret` from
`POST /api/v1/donations/intent/` on the hub API — **that endpoint does
not exist** (`donations/urls.py` = list/detail/refund only), so the
donation card flow is a dead path: no live payment processing in hub AT
ALL. PAN cannot transit hub because no payment transit exists.

**C2 verdict: PASS today (no PAN path, hostile attempt blocked), on the
caveat that protection currently rests on absence, not on enforced
controls.**

---

## C3 — Contract regression (Step 13 suite) — NOT EXECUTABLE

- Step 13 artifacts do not exist in any fleet repo (searched
  `STEP*`, `tests/**` across all four market repos + hub).
- The contract surface itself is unimplemented: `payments_app/urls.py`
  exposes ONLY `stripe/` (the Stripe webhook). No `/internal/v1/*`
  endpoints, no mTLS config, no HMAC layer, no caller registry, no
  hub-facing webhook forwarder.
- Consumer-driven contract tests: none (marketplace `tests/unit/` =
  fingerprint/idempotency semantics, encryption, state machine — generic
  core tests, not the payment contract).

Binding, 404-non-enumeration, idempotency-replay, PAN-leak, dedup,
degraded-mode suite: **cannot re-run what was never built.** G3 gate
evidence checklist confirms (all items unchecked).

**C3 verdict: FAIL (unimplemented) — recorded, not waived.**

---

## C4 — Webhook integrity — PARTIAL PASS (code-level, SDK-verified)

Controlled tests against the same SDK major version class (stripe 14.4.0):

```text
FORGE: rejected -> SignatureVerificationError; subclass-of-ValueError: False
VALID: parsed -> evt_audit_001 payment_intent.succeeded
```

- Forged signature → rejected (SDK-level HMAC verification works).
- Valid signature → parses; `webhooks.py` persists BEFORE dispatch,
  dedup by `StripeWebhookEvent.event_id` (unique constraint) +
  `get_or_create` guard → replay-safe (code-verified; DB-level execution
  untestable without a running stack).
- **Defect found:** `webhooks.py` catches only `ValueError`;
  `SignatureVerificationError` is NOT a ValueError subclass → a forged
  webhook yields HTTP 500, not 400. Integrity holds (never accepted),
  error semantics wrong; registered as residual.
- Per-product forwarding to hub (`X-Product: hub` signed delivery):
  NOT implemented — nothing forwards anywhere.

**C4 verdict: ingestion integrity PROVEN at SDK/code level; forwarding
and live replay drill missing.**

---

## C5 — Revenue attribution — FAIL (contract not honored: unimplemented)

`PaymentRecord` (payments_app/models.py) fields: order FK, intent id,
amount, currency, status, refunded_amount. **No `product` field.**
`create_payment_intent` metadata = `{order_id, order_number}` only.
No hub intents exist; no finance-mart contract artifact found in
`jol-m-data`. Hub-donation vs marketplace-order separation is currently
trivial (hub side = zero transactions) but NOT by the contracted design.

**C5 verdict: FAIL — attribution schema must be built per contract §5
before the first hub donation.**

---

## C6 — Degraded mode — PARTIAL (structural proof only)

No running boundary to fail over from. Structural proof: hub has no code
path AND no credential AND (by F1's remediation target) soon no SDK to
bypass with; the frontend surfaces server failures as
`DonationError{type:'server', retryable:true}`. **Bypass is impossible
in the current codebase; a live outage drill is owed once the boundary
exists** (registered).

---

## C7 — PCI scope statement — ISSUED (this step)

Filed to `jol-m-compliance/certifications/pci-dss/scope-statement-model-a.md`
and archived with this report under
`jol-m-compliance/audits/internal/2026-08-step17-payment-boundary-audit/`.
Statement:

> SAQ-A scope = the payment boundary (`jol-m-marketplace`
> `payments_app`, its data stores and network segment) ONLY. jol-hub is
> OUT of scope per Model A (ADR-0005, ADR-0004 Amendment 1): no Stripe
> SDK server-side, no Stripe keys, no PAN, no `api.stripe.com` path.
> Controls: PCI-DSS v4.0 Req. 12.5.2 (this statement + quarterly
> reconfirmation), Req. 1.x (network-policy matrix), GDPR Art. 5(1)(b),
> SOC 2 CC6.1 (boundary access: mTLS + caller binding when implemented),
> ISO 27001 A.8.13 (segregation with a documented interface).
> **Audit status 2026-08-17:** statement holds in source; E1/E2/E3
> operationalization and the internal API are open (see residuals).

Steps 13–16 reports: DO NOT EXIST — cannot be archived. This STEP 17
report is the first gate evidence filed under G3.

---

## C8 — Residual risks (filed in jol-m-compliance/risk-register/register.md)

| ID | Residual | Owner |
|----|----------|-------|
| RSK-006 | Hub Model-B residue (PB-01…PB-06): stripe dep, key plumbing, infra secrets, providers config, inverted test | Platform |
| RSK-007 | E1/E2 guards not wired in hub CI (allowed RSK-006 to accumulate) | Platform |
| RSK-008 | E3 network control not deployed; hostile-attempt defense rests on credential absence | Infra |
| RSK-009 | Internal payment API unimplemented: donation flow dead-ended; pressure risk to re-integrate directly | Marketplace |
| RSK-010 | Refund edge cases: hub refund view flips DB status only — no money movement via boundary; partial/duplicate-refund paths undefined | Marketplace |
| RSK-011 | Donation VAT/receipt handling unresolved (receipt endpoints exist as stubs) — routed to jol-m-legal + tax advisor; recurring donations undesigned against contract | Compliance/Legal |
| (defect) | Webhook forgery → HTTP 500 instead of 400 (exception-class mismatch) | Marketplace |

---

## Remediation order (audit recommendation)

1. Purge PB-01…PB-06 from jol-hub (deps, settings/secrets/vault plumbing,
   infra manifests, providers config, inverted test) — one PR, then
   wire `check-payment-boundary.sh` + dependency-guard test into hub CI
   BEFORE anything else lands (closes RSK-006/007).
2. Implement `/internal/v1` per `docs/payment-api-contract.md` with the
   `product` field and caller binding; consumer-driven contract tests
   gate both sides (closes RSK-009, C3, C5).
3. Fix webhook exception handling (400 on forged signature).
4. Deploy E3 rows with the payment workstream; re-run THIS audit
   (hostile attempt included) against the live boundary (closes RSK-008).
5. Quarterly: re-run E1–E3 + hostile attempt; reconfirm scope statement.

## ONE-SENTENCE VERDICT

**Model A single-payment-boundary is NOT PROVEN — ownership holds in
source today (payments_app is the only Stripe consumer; the hostile
hub→Stripe attempt failed for lack of any valid credential and any code
path), but two of three structural controls are not operational (E1/E2
guards absent from hub CI, E3 not deployed), six items of dormant Model-B
residue were found in jol-hub (PB-01…PB-06), and the contracted internal API —
including revenue attribution and hub webhook forwarding — is not yet
implemented; all findings are owned and registered (RSK-006…RSK-011).**
