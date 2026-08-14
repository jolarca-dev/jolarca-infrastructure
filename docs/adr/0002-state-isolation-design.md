# ADR-0002: Terraform state isolation design

- **Status:** Accepted
- **Date:** 2026-08-14
- **Deciders:** infra operators (names in compliance record)

## Context

Terraform state is the highest-value artifact in this repository's blast
radius: it maps the entire topology. A shared or casually stored state is
an audit failure waiting to happen.

## Decision

1. One state per environment (`staging`, `production`); never shared.
2. Remote state in dedicated GCS buckets: separate bucket, separate CMEK,
   separate service account per environment (`terraform/backends/`).
3. Object versioning + retention; an independent backup layer
   (`backup/terraform-state/`).
4. Human write access only via break-glass, always audited.
5. Policy gate: `require-cmek.rego` blocks buckets without CMEK.

## Consequences

- (+) Leak of one environment's state does not expose the other.
- (+) CMEK revocation renders stolen copies unreadable.
- (−) Bootstrap is more complex (chicken-and-egg bucket provisioning;
  see `terraform/modules/state-bucket/README.md`).

## Compliance mapping

SOC 2 CC6.1/CC6.6, ISO 27001 A.8.24 (use of cryptography), GDPR Art. 32.
