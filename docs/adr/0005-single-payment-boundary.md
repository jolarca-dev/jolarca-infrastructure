# ADR-0005: Two Django projects + single payment boundary (Model A)

- **Status:** Accepted (operator decision, ratified 2026-08-17)
- **Date:** 2026-08-17
- **Deciders:** org owner (solo era)
- **Amends:** ADR-0004 (single sanctioned exception recorded there as Amendment 1)
- **Contract:** [`docs/payment-api-contract.md`](../payment-api-contract.md)

## Context

Two separate Django projects live in one org:

| Project | Product | Repo / local tree | Compliance posture |
|---|---|---|---|
| jol-hub | Roman Catholic digital mission platform (mission-program flagship) | `jol-hub`, `/opt/jol/repos/` | GDPR (religious-context processing); NO card scope |
| jol-m-marketplace | Baltic B2C/B2B2C marketplace | `jol-m-marketplace`, `/opt/jol-m/repos/` | PCI-DSS (Stripe), GDPR, KYC/AML, VAT OSS |

Both products take card payments: marketplace orders and hub donations.
Two integration models were considered:

- **Model A** — ONE Stripe integration. The marketplace `payments_app` is
  the sole payment boundary; jol-hub consumes it through an internal
  payment API.
- **Model B** — two independent Stripe integrations, one per project.

Model A was ratified by operator decision. Its entire value is that
jol-hub stays OUT of PCI scope — so this ADR does not merely describe
the design, it makes hub reaching Stripe **structurally impossible**
(code, dependency, and network controls), not merely discouraged.

## Decision — Model A (ratified)

1. **One Stripe platform account**, owned by the marketplace
   `payments_app`. ONLY that service speaks to Stripe server-side, holds
   Stripe API keys, and receives Stripe webhooks.
2. **jol-hub is a client of the boundary, never a peer to Stripe.** Hub
   consumes the internal payment API defined in
   [`docs/payment-api-contract.md`](../payment-api-contract.md). Hub
   never imports the Stripe SDK server-side, never holds Stripe keys,
   never sees PAN data.
3. **PCI scope = the boundary only.** One SAQ-A scope: `payments_app` +
   its data stores + its network segment (`security/pci-dss-scope.md`).
   jol-hub is provably out of scope; the quarterly scope reconfirmation
   re-verifies the three enforcement controls below.
4. **SAQ-A preserved end-to-end.** Card data flows
   donor/customer browser → Stripe directly (Stripe Elements with the
   PaymentIntent `client_secret`). No PAN ever transits hub OR the
   payment service server-side; the internal API carries only
   `client_secret`s and status tokens.

### Structural enforcement (E1–E3)

| # | Control | Location | Fails when |
|---|---------|----------|------------|
| E1 | CI grep in jol-hub — [`scripts/check-payment-boundary.sh`](../../scripts/check-payment-boundary.sh) is the record copy, pinned into hub CI | hub PR gate | Stripe SDK imports/use, Stripe key patterns, `STRIPE_SECRET`, or `api.stripe.com` appear in hub server code |
| E2 | Dependency allow-list guard | hub requirements/pyproject + guard test | the `stripe` package appears anywhere in hub's dependency set |
| E3 | Network policy — no hub egress to `api.stripe.com`; only `payments_app` holds an allow row | [`security/network-policy.md`](../../security/network-policy.md) "Payment boundary" matrix | any hub workload can reach Stripe directly (implemented when the payment-boundary workstream lands; the matrix rows are its acceptance criteria) |

E1+E2 block the violation in code; E3 blocks it at runtime even if a
code-level control is bypassed. The one sanctioned hub-side Stripe
artifact is the browser-only Stripe.js/Elements include (`js.stripe.com`)
required by the SAQ-A donation flow — see contract §4.5.

### Fleet placement — jol-hub naming resolved

- The mission prefix in ADR-0004 R1 is `jol-*` (without `m`); `jol-c-*`
  never existed in the doctrine (GATE-0 preflight confirmed the earlier
  mention was a typo). **`jol-hub` complies as-is** — it is the mission
  program's flagship, requiring neither a rename nor a naming exception.
- Local root: `/opt/jol/repos/jol-hub` (mission tree, ADR-0004 R5: one
  project root per IDE window; agent context never spans both projects).
- Terraform: jol-hub is **deliberately NOT added** to
  `terraform/modules/github-org`. That module's jurisdiction is the
  marketplace fleet only: its validation rejects non-`jol-m-*` keys
  (R1/R3), R4 forbids a marketplace module from managing a mission repo,
  and mission resources must never enter marketplace Terraform state
  (PCI-adjacent custody). `jol-hub` creation/management belongs to the
  mission program's own IaC (future mission infra root under
  `/opt/jol/repos/`); R2 (Terraform-only creation) is scoped to the
  marketplace fleet, so out-of-band creation of `jol-hub` is not an
  incident. The fleet guard (`scripts/check-fleet-separation.sh`)
  compares only the org's `jol-m-*` set and is unaffected.

## Rejected — Model B (two Stripe integrations)

Two integrations = two PCI scopes, two SAQ attestations, two Stripe DPAs
(two RoPA entries), double audit cost, and two independent drift surfaces
where a hub-side Stripe integration could quietly expand scope. It also
duplicates webhook handling, refund tooling, and revenue reconciliation.
Model B buys nothing the org needs (there is no billing-separation
requirement today — cf. ADR-0004 R7 split triggers) and permanently
defeats Model A's core benefit: hub outside PCI scope. Rejected.

## Consequences

- (+) jol-hub is OUT of PCI scope — the major compliance win; its audit
  surface stays GDPR-only.
- (+) ONE Stripe DPA covers both products → one RoPA entry for Stripe
  processing; simpler vendor management and DPIA coverage.
- (−) Requires a hardened internal payment API: mTLS, HMAC-signed
  requests with replay TTL, mandatory idempotency keys, service-account
  caller binding (contract §3–§4). This is the price of the single scope.
- (−) The Two-Program Doctrine (ADR-0004) gains ONE sanctioned
  cross-program exception — the payment API (Amendment 1). No other
  cross-program code dependency may ever be added without a new ADR.
- (−) The payment boundary is a shared dependency: hub donation
  availability now depends on `payments_app`. Mitigation: contract §9
  degraded-mode rules; unavailability of donations is degraded service,
  never a reason to bypass the boundary.
- (−) Single point of revenue processing for both products; outage
  handling and refund tooling concentrate in `payments_app` (reflected
  in the risk register, below).

## Risk-register + RoPA notes

Custody: the risk register lives ONLY in `jol-m-compliance/risk-register`
(single-source-of-truth custody decision); entries below are filed there,
not duplicated here.

1. **Single payment boundary as a designed control** — register as a
   compensating-control set: E1–E3 + contract security requirements;
   review quarterly with the PCI scope reconfirmation.
2. **One Stripe DPA covering both products** — one RoPA entry; record
   the two processing purposes (marketplace orders; hub donations) under
   that single processor relationship.
3. **Donation-data lawful basis** — donations processed in a
   religious-context platform may touch GDPR Art. 9 categories; the
   lawful basis for donor data is FLAGGED FOR DPO REVIEW — do not assume
   it. Same flag pattern for VAT: donations are typically outside VAT
   scope, but this is FLAGGED FOR THE TAX ADVISOR, not assumed
   (contract §5).

## Compliance mapping

PCI-DSS v4.0 Req. 12.5.2 (scope confirmation — hub provably out of CDE);
Req. 1.x (segmentation via network-policy matrix); GDPR Art. 5(1)(b)
(purpose limitation preserved: mission vs marketplace processing stay
distinct, only the payment boundary is shared); Art. 28/30 (single
processor DPA, single RoPA entry); SOC 2 CC6.1 (logical access to the
boundary: mTLS + caller binding); ISO 27001 A.8.13 (segregation with a
documented, controlled interface).
