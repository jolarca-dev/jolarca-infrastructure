# Payment API integration contract (Model A — ADR-0005)

- **Status:** Contract v1 (frozen for implementation; change rules in §8)
- **Date:** 2026-08-17
- **Authority:** ADR-0005 (ratified); ADR-0004 Amendment 1 (the single
  sanctioned cross-program interface)

| Role | Party | Position |
|------|-------|----------|
| Provider | `payments_app` in `jol-m-marketplace` | sole Stripe integrator, sole PCI/SAQ-A scope |
| Consumer | `jol-hub` (mission platform) | client of the boundary; never a peer to Stripe |

This document is implementable as written: endpoint shapes, auth,
idempotency, webhook routing, revenue attribution, and the hub donation
flow. **No payment code exists yet** — implementation is a later, gated
workstream (roadmap in `STEP10_PAYMENT_BOUNDARY.md`).

---

## 1. Invariants (read first)

1. One Stripe platform account, owned by `payments_app`. Only
   `payments_app` speaks to Stripe server-side, holds Stripe keys, and
   receives Stripe webhooks.
2. No PAN ever crosses this API — in either direction. The API carries
   only PaymentIntent ids, `client_secret`s, status tokens, and amounts.
3. Card data flows donor/customer browser → Stripe directly (Stripe
   Elements). Never through hub, never through the payment service
   server-side. SAQ-A is preserved end-to-end.
4. Hub invariants (structurally enforced, ADR-0005 E1–E3): no `stripe`
   server-side import, no Stripe keys, no `api.stripe.com` egress.

## 2. API surface

Base path: `/internal/v1` on the payment service's internal endpoint
(resolution deferred to implementation: WireGuard-mesh service address;
NOT exposed on the public ingress, `security/isolation-model.md`
boundary 3/4). All bodies are `application/json; charset=utf-8`. All
amounts are integer minor units.

### 2.1 `POST /internal/v1/payment-intents` — create intent

Creates a Stripe PaymentIntent for a donation OR a marketplace order.

Request body:

```json
{
  "product": "hub",
  "amount_cents": 2500,
  "currency": "EUR",
  "metadata": {
    "campaign_id": "advent-2026",
    "purpose": "donation"
  },
  "customer_ref": "hub-dnr-7f3a9c"
}
```

| Field | Rule |
|-------|------|
| `product` | `"hub"` or `"marketplace"` — MUST match the authenticated caller (§4.4); mismatch = `403` |
| `amount_cents` | integer > 0; provider enforces per-product min/max caps |
| `currency` | `"EUR"` only in v1; any other value = `422` (new currency = contract amendment, §8) |
| `metadata` | flat string→string map; provider copies sanctioned keys onto the Stripe object for revenue attribution (§5). PII-free by policy: no names, emails, addresses |
| `customer_ref` | pseudonymized caller-side reference (e.g. hashed donor/order id). The provider stores it verbatim and echoes it back; it must never allow re-identification by the provider |

Response `201 Created` (or `200` on idempotent replay):

```json
{
  "id": "pi_internal_01J5XK9",
  "product": "hub",
  "status": "requires_payment_method",
  "amount_cents": 2500,
  "currency": "EUR",
  "client_secret": "pi_..._secret_...",
  "customer_ref": "hub-dnr-7f3a9c",
  "expires_at": "2026-08-17T14:30:00Z"
}
```

`client_secret` is returned ONLY on create (and idempotent replay of
the same create), never on `GET`. It is single-use material: consumers
must not log, cache, or persist it.

### 2.2 `GET /internal/v1/payment-intents/{id}` — status query

Response `200 OK`:

```json
{
  "id": "pi_internal_01J5XK9",
  "product": "hub",
  "status": "succeeded",
  "amount_cents": 2500,
  "currency": "EUR",
  "customer_ref": "hub-dnr-7f3a9c",
  "created_at": "2026-08-17T14:00:00Z",
  "finalized_at": "2026-08-17T14:02:11Z"
}
```

Status vocabulary (closed set; unknown values are a contract violation):

| Status | Meaning |
|--------|---------|
| `requires_payment_method` | intent created, awaiting card entry |
| `processing` | Stripe is processing the charge |
| `succeeded` | captured; terminal success |
| `failed` | charge failed; terminal failure |
| `canceled` | canceled or expired; terminal |
| `refunded` | fully refunded; terminal |
| `partially_refunded` | partial refund applied; non-terminal for further refunds |

Reads are caller-scoped: hub may only read `product: "hub"` intents.

### 2.3 `POST /internal/v1/refunds` — refund

```json
{
  "payment_intent_id": "pi_internal_01J5XK9",
  "amount_cents": 2500,
  "reason": "donor_request_duplicate"
}
```

`amount_cents` optional (absent = full refund); `reason` mandatory
(free-text enum seed values: `donor_request_duplicate`,
`donor_request_error`, `order_canceled`, `order_undeliverable`,
`other` — `other` requires an accompanying `reason_detail`). Response
`201 Created`: `{id, payment_intent_id, status, amount_cents, currency}`
with refund status `pending | succeeded | failed`. Refunds are only
permitted against `succeeded` / `partially_refunded` intents, and only
by the owning product caller.

### 2.4 Errors

`application/problem+json` (RFC 9457): `{type, title, status, detail,
instance}`. Codes used: `400` malformed, `401` auth/signature failure,
`403` caller/product mismatch, `404` not-found-or-not-yours (never
reveal existence of another caller's intents), `409` idempotency-key
reuse with a different body, `422` business-rule violation, `429` rate
limit. Error bodies never contain card data or `client_secret`s.

## 3. Webhook routing

1. Stripe webhooks land ONLY on `payments_app` (its Stripe-facing
   webhook endpoint; signature verified against the Stripe endpoint
   secret). Hub registers NOTHING with Stripe.
2. `payments_app` maps each event to a product by the PaymentIntent's
   `product` attribution, then forwards per-product events to the
   product owner over a signed internal webhook:
   `POST {hub}/internal/v1/payment-events` with header `X-Product: hub`
   (§4.2 signature scheme, delivery key held by the provider).
3. Event envelope (PAN-free by construction):

   ```json
   {
     "event_id": "evt_01J5XKB2",
     "type": "payment_intent.succeeded",
     "product": "hub",
     "payment_intent_id": "pi_internal_01J5XK9",
     "status": "succeeded",
     "amount_cents": 2500,
     "currency": "EUR",
     "occurred_at": "2026-08-17T14:02:11Z"
   }
   ```

4. Delivery semantics: at-least-once with retry/backoff (provider-side
   durable queue; retries over ≥24h before dead-lettering). Hub MUST
   deduplicate by `event_id` and MUST treat order as not guaranteed
   (reconcile via §2.2 on conflict). Hub MUST NOT call Stripe to verify
   anything — §2.2 is the only verification path.

## 4. Security requirements (non-negotiable)

### 4.1 mTLS

Hub presents a client certificate; the payment service verifies it
against the internal CA and a per-caller allow-list (cert subject/SAN
pinned to the registered caller identity). Short-lived certs, rotation
per the key-custody doctrine; a failed handshake is a hard reject. Same
requirement applies to the reverse direction (§3 provider→hub webhook
delivery).

### 4.2 Signed requests + replay protection

Every request carries:

| Header | Value |
|--------|-------|
| `X-JOL-Caller` | registered caller id (`hub-payments`, `marketplace-internal`) |
| `X-JOL-Timestamp` | unix seconds at send time |
| `X-JOL-Signature` | `base64(HMAC-SHA256(K_caller, "{ts}.{method}.{path}.{sha256hex(body)}"))` |

The provider rejects timestamps older than 60 s (TTL; NTP required on
both sides). Per-caller HMAC keys live in the secret store (Vault),
never in git/env files committed anywhere, and rotate on schedule. The
signature binds method+path+body so no captured request can be
re-targeted; the TTL defeats replay within the capture window and the
Idempotency-Key defeats semantic replay (§4.3).

### 4.3 Idempotency

`Idempotency-Key` header is MANDATORY on every mutating call
(payment-intent create, refund). The provider stores (caller, key) →
response for ≥24 h; a replay with an identical body returns the stored
response (same status code). Same key with a different body = `409`.
Consumers generate keys from their own domain ids (e.g. hub donation
record id) so retries after timeouts never double-charge.

### 4.4 Caller authentication & authorization

The payment service authenticates hub as a **service account**
(`hub-payments`), never with end-user credentials. Authorization
bindings (server-enforced, not client-honored):

| Caller | May create/read/refund |
|--------|------------------------|
| `hub-payments` | `product: "hub"` only |
| `marketplace-internal` | `product: "marketplace"` only |

Any product/caller mismatch = `403`, logged as a security event.

### 4.5 PAN prohibition (SAQ-A preservation)

- The API payloads in §2–§3 structurally contain no card fields; the
  provider never serializes Stripe card objects into internal
  responses. Any change that adds card data to this API is a CRIT-class
  change requiring a new ADR (`security/pci-dss-scope.md`).
- Hub's ONLY sanctioned Stripe-facing artifact is the browser-side
  Stripe.js/Elements include loaded from `js.stripe.com` (rendering the
  donation form; card data goes donor browser → Stripe). `api.stripe.com`
  remains forbidden to hub on every plane (E1/E3).
- `client_secret`s and webhook signatures must never appear in logs on
  either side.

### 4.6 Audit logging

The provider logs every call: caller id, endpoint, idempotency key,
status code, latency — never request bodies (which could carry
metadata). Logs are part of the CDE audit trail (PCI-DSS Req. 10).

## 5. Revenue attribution & tax

- Every intent carries `product` + `metadata`; the provider copies
  sanctioned metadata keys (e.g. `campaign_id`, `order_ref`, `purpose`)
  onto the Stripe PaymentIntent so Stripe reporting and the internal
  ledger split **hub-donation vs marketplace-order revenue** without
  ambiguity. Finance reconciliation consumes the provider's attribution
  view, keyed by `product`.
- VAT/OSS handling lives ENTIRELY inside the marketplace boundary
  (marketplace orders are taxable supplies; invoicing there).
- Hub donations are typically outside VAT scope — **flagged for the tax
  advisor, not assumed**. Until confirmed, the provider's ledger tags
  hub revenue `vat_treatment: tbd_donations` (ADR-0005 risk notes).
- Donor-data lawful basis for the mission platform is flagged for DPO
  review (ADR-0005 risk notes); the pseudonymized `customer_ref` is the
  only donor-linked value crossing the boundary.

## 6. Donation flow (hub-specific)

1. Donor chooses an amount/campaign in jol-hub; hub creates a local
   donation-intent record (amount, campaign, pseudonymized donor ref).
2. Hub → `POST /internal/v1/payment-intents` (`product: "hub"`,
   `Idempotency-Key` = donation record id).
3. Provider creates the Stripe PaymentIntent and returns `client_secret`.
4. Hub renders Stripe Elements with the returned `client_secret`
   (Stripe.js in the donor's browser). Card data goes donor browser →
   Stripe directly; hub's server never sees it.
5. Stripe confirms the payment → webhook → `payments_app` → signed
   internal webhook (§3) → hub.
6. Hub records the donation: amount + status + timestamp only. No card
   data, ever.
7. Failure/abandonment: the intent expires (`expires_at`); hub may poll
   §2.2 with backoff or simply await the webhook. Donor retries reuse
   the same Idempotency-Key → no double charge.

Marketplace orders use the identical API surface with
`product: "marketplace"` from `marketplace-internal`; the marketplace's
existing checkout flows are otherwise unchanged.

## 7. Availability & degraded mode

- The boundary is a shared dependency (ADR-0005 consequence): when the
  payment service is unreachable, hub shows a degraded donation form
  ("donations temporarily unavailable") and retries with exponential
  backoff + jitter. No polling storms; no circuit-breaker-open bypass.
- Boundary unavailability is degraded service, NEVER a reason to
  integrate Stripe directly in hub — that path is structurally closed
  (E1–E3).
- Provider webhook delivery is backed by a durable queue (§3.4) so a
  hub outage cannot lose payment events.

## 8. Versioning & change rules

- Additive changes only within `/internal/v1` (new optional fields, new
  status values are NOT additive for consumers — they require v2).
- Breaking change = `/internal/v2` with a dual-run window; consumers
  migrate on their own schedule within the announced window.
- Consumer-driven contract tests gate BOTH sides (§9); any change
  failing the consumer suite is rejected.
- Changes to THIS document follow the infra change process (PR + risk
  class per `QODER.md`); security-requirement changes (§4) additionally
  require security review (`security/isolation-model.md`).

## 9. Test plan — contract tests FIRST

Implementation order is gated (full roadmap in
`STEP10_PAYMENT_BOUNDARY.md`):

1. **Contract fixtures + consumer-driven tests** on both sides:
   request/response schemas for §2.1–§2.4, webhook envelope §3.3.
2. **Security tests:** mTLS handshake rejected without client cert;
   signature rejection on tamper + on expired timestamp (replay);
   idempotent replay returns stored response; key+body mismatch = 409;
   caller/product mismatch = 403.
3. **Webhook tests:** dedup by `event_id`; out-of-order delivery
   reconciled via §2.2; retry/backoff then dead-letter.
4. **PAN-leak test:** response-schema assertion that no response or
   webhook envelope contains card fields (regression guard for §4.5).
5. **Boundary tests (hub repo):** `scripts/check-payment-boundary.sh`
   green + dependency-guard test green (ADR-0005 E1/E2).
