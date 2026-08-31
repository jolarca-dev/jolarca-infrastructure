# STEP 10 — Payment Boundary (Model A): Architecture Record & Gate

Operator-facing record for the ratified payment-boundary step. This step
is ARCHITECTURE ONLY: it writes the ADR and the integration contract.
**No payment code has been written** — implementation is a later, gated
workstream (roadmap below). Risk class of the *implementation* phase:
High (network + secrets + PCI scope) — 2-person rule + rollback plan
when it lands (`QODER.md`).

Codified artifacts:

| Artifact | Location |
|----------|----------|
| ADR-0005 — Two Django projects + single payment boundary (Model A) | `docs/adr/0005-single-payment-boundary.md` |
| ADR-0004 Amendment 1 — the single cross-program exception | `docs/adr/0004-mission-marketplace-separation.md` |
| Payment API integration contract v1 | `docs/payment-api-contract.md` |
| E1 guard (record copy) | `scripts/check-payment-boundary.sh` |
| E3 network-policy matrix | `security/network-policy.md` (§ payment boundary) |

---

## A1 — ADR summary (Model A, ratified)

- ONE Stripe platform account, owned by the marketplace `payments_app`;
  it is the sole PCI/SAQ-A boundary. Only it speaks to Stripe
  server-side, holds Stripe keys, and receives Stripe webhooks.
- jol-hub is a CLIENT of the boundary via the internal payment API —
  never a peer to Stripe. PCI scope = the boundary only.
- SAQ-A end-to-end: card data goes donor/customer browser → Stripe
  (Elements with the `client_secret`); no PAN touches hub or the
  payment service server-side.
- Rejected: **Model B** (two integrations → two PCI scopes, two DPAs,
  double audit cost, two drift surfaces). Rationale in ADR-0005.
- Two-Program Doctrine (ADR-0004) amended with its ONE documented
  exception: the payment API. Cross-program code dependency remains
  forbidden everywhere else; any further exception needs a new ADR.

## A2 — Contract essentials (full text: `docs/payment-api-contract.md`)

API surface (provider: `payments_app`, consumer: jol-hub):

| Endpoint | Purpose |
|----------|---------|
| `POST /internal/v1/payment-intents` | create intent (donation OR order); `{product, amount_cents, currency:"EUR", metadata, customer_ref}` + mandatory `Idempotency-Key`; returns `client_secret` once |
| `GET /internal/v1/payment-intents/{id}` | status query (closed status vocabulary; caller-scoped) |
| `POST /internal/v1/refunds` | refund with mandatory `reason` + `Idempotency-Key` |
| Webhook routing | Stripe → payments_app ONLY → signed internal webhook to hub (`X-Product: hub`), at-least-once, dedup by `event_id` |

Non-negotiable security requirements: mTLS both directions; HMAC-SHA256
request signatures over body+timestamp with 60 s replay TTL; mandatory
idempotency on all mutating calls; service-account caller identity with
server-enforced caller↔product binding; PAN-free payloads; audit
logging without bodies. Revenue attribution via `product` + sanctioned
metadata keys (hub-donation vs marketplace-order split; VAT/OSS inside
the marketplace boundary; donation VAT status flagged for the tax
advisor, donor-data lawful basis flagged for DPO — neither assumed).
Donation flow: hub donation record → create intent → render Elements
with `client_secret` → Stripe confirms → webhook chain → hub records
amount + status only (contract §6).

## A3 — Enforcement checklist (structural, not advisory)

| # | Mechanism | Check | Status |
|---|-----------|-------|--------|
| E1 | CI grep in jol-hub | `bash scripts/check-payment-boundary.sh /opt/jol/repos/jol-hub` → exit 0 required in hub CI; fails on Stripe SDK imports/use, key patterns, `STRIPE_SECRET`, `api.stripe.com` | ✅ record copy landed + negative-tested; pin into hub CI when the repo exists |
| E2 | Dependency allow-list | `stripe` absent from hub requirements/pyproject; dependency-guard test in hub suite fails on addition (layer-1 manifest scan in E1 is its CI twin) | ☐ lands with the hub repo scaffold |
| E3 | Network policy | hub egress to `api.stripe.com` denied by absence of any allow row; only `payments_app` holds the Stripe egress row (`security/network-policy.md`) | ☐ future workstream — matrix rows are its acceptance criteria |

Local verification run this step (guard tested both directions):

```bash
shellcheck scripts/check-payment-boundary.sh          # clean
bash scripts/check-payment-boundary.sh <clean-tree>   # exit 0 (js.stripe.com Elements include passes — SAQ-A)
bash scripts/check-payment-boundary.sh <violating-tree>  # exit 1: SDK import, stripe dep, STRIPE_SECRET, sk_test_ all flagged
```

## A4 — Fleet map & placement decision

- **Naming resolved:** `jol-hub` IS the mission prefix (`jol-*` without
  `m`, ADR-0004 R1; `jol-c-*` never existed in the doctrine — GATE-0
  preflight confirmed the earlier mention was a typo). Flagship of the
  mission program; no rename, no naming exception needed.
- **Local root:** `/opt/jol/repos/jol-hub` (mission tree; one project
  root per IDE window, agent context never spans projects).
- **Terraform:** NOT added to `terraform/modules/github-org` — by
  design, not by omission. The module's jurisdiction is `jol-m-*` only
  (validation rejects anything else); R4 forbids a marketplace module
  managing a mission repo; mission resources must never enter
  marketplace state. jol-hub management belongs to mission-program IaC
  (future mission infra root under `/opt/jol/repos/`). R2's
  Terraform-only rule is scoped to the marketplace fleet, so creating
  `jol-hub` out-of-band is not an incident. The fleet guard compares
  only the org's `jol-m-*` set and is unaffected (verified by design:
  `scripts/check-fleet-separation.sh` greps `^jol-m-`).

## A5 — Risk-register + RoPA follow-ups (file in `jolarca-compliance/risk-register`)

1. Single payment boundary registered as a designed compensating-control
   set (E1–E3 + contract §4); quarterly review with PCI scope
   reconfirmation (`security/pci-dss-scope.md`).
2. ONE Stripe DPA covering both products → ONE RoPA entry with two
   processing purposes (marketplace orders; hub donations).
3. Donation-data lawful basis (religious-context platform, potential
   GDPR Art. 9 adjacency) → DPO review flag. Donation VAT treatment →
   tax-advisor flag. Ledger tag until then: `vat_treatment:
   tbd_donations`.

## A6 — Implementation roadmap (gated; NOT part of this step)

1. **Contract tests first.** Consumer-driven contract fixtures for
   endpoints + webhook envelope on BOTH sides; security tests (mTLS
   reject, signature tamper/replay, idempotency replay, 409/403 paths);
   PAN-leak schema regression test (contract §9).
2. **Provider endpoints.** `payments_app` implements `/internal/v1` +
   webhook forwarder behind the contract suite.
3. **Hub donation flow.** jol-hub implements §6 of the contract with
   E1/E2 gates live in its CI (before first donation goes live).
4. **Marketplace flows:** already exist internally; migrate to the
   `marketplace-internal` caller identity — no behavior change.
5. **E3 runtime enforcement.** NetworkPolicy/NAT allow-list rows as the
   payment workstream deploys; then quarterly scope reconfirmation.

## Acceptance criteria — evidence map

| Criterion | Evidence |
|-----------|----------|
| Model A ratified; PCI scope = single boundary; Model B rejection recorded | ADR-0005 Decision / Rejected sections |
| Contract concrete enough to implement from | `docs/payment-api-contract.md` §2–§6 (endpoints, mTLS, idempotency, donation flow, revenue attribution) |
| Three structural enforcement mechanisms | ADR-0005 E1–E3 + `scripts/check-payment-boundary.sh` (tested) + network-policy matrix |
| Two-Program Doctrine amended with the single payment exception; jol-hub placed | ADR-0004 Amendment 1; ADR-0005 fleet placement; `variables.tf` note |
| No payment code written | this step touches only docs/scripts/security-docs — no application code |
