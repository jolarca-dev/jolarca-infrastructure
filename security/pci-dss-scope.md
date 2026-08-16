# PCI-DSS scope — cardholder data environment (CDE) segmentation

**Applies to:** marketplace payments + KYC/AML workloads declared in
`jol-m-marketplace`. PCI-DSS v4.0; this document defines what is IN scope
so everything else can be provably OUT of scope (Req. 12.5.2 scope
confirmation, quarterly).

## In-scope systems (CDE)

- Payment processing services (PSP integration) and anything that stores,
  processes, or transmits cardholder data (CHD) or sensitive
  authentication data (SAD — never stored, period).
- Their databases, queues, caches, and object storage paths.
- The network segments those systems run in, and every system connected to
  those segments — including security systems (Req. 12.5.2).
- The bare-metal DB hosts and the GKE namespaces hosting payment services.

## Scope-reduction design (by construction)

1. **PSP-first:** card data goes directly to the payment service provider;
   our systems hold tokens, never PANs. This keeps the footprint at
   SAQ-level minimal; any regression here is a CRIT-class change.
2. **Segmented namespace/hosts:** payment workloads run in dedicated
   hosts/namespaces; default-deny network policy isolates them
   (`network-policy.md`). Cross-segment flows need a row in that matrix.
3. **No CHD in logs, backups-in-plaintext, or state.** Borg backups of
   payment DBs are encrypted (borg repokey) and their restore path is
   drilled (`../backup/restore-drill.md`).
4. **Terraform state of payment segments** contains no CHD by design;
   still treated as connected-to-CDE for access control (read = need to
   know, logged).
5. **Mission platform out of scope by construction (ADR-0005).** jol-hub
   consumes the payment boundary as a client (`docs/payment-api-contract.md`):
   no Stripe SDK server-side, no Stripe keys, no PAN, no network path to
   `api.stripe.com`. Its exclusion from the CDE is re-verified with the
   quarterly scope reconfirmation (E1–E3 controls).

## Obligations carried by THIS repository

| PCI-DSS Req | How this repo serves it                                   |
|-------------|------------------------------------------------------------|
| 1.x         | default-deny matrices, documented per-flow purpose          |
| 2.x         | CIS baseline (`cis-baseline.md`)                            |
| 3.x         | no SAD storage; tokenization-first design declared here     |
| 7/8         | least-privilege IAM, dual control (`key-custody.md`)        |
| 10          | auditd + compliance log sink; time sync                     |
| 12.5.2      | this document + quarterly reconfirmation in `access-review.md` |

## Quarterly scope reconfirmation

Recorded in `access-review.md`: verify no new system became
connected-to-CDE since last review. Evidence goes to `jol-m-compliance`.
