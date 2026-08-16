# Isolation model — THE MOAT DOCTRINE

**Status:** doctrine (applies from day one, including to the currently
landed GitHub-org Terraform). Changes require security review.

## Purpose

Define trust boundaries for the marketplace infrastructure and state
categorically what may never leave this repository. Basis: ISO 27001:2022
A.5.2 (policies for information security), A.8.13 (segregation); SOC 2
CC6.1 (logical access); GDPR Art. 32 (security of processing).

## Trust boundaries

| # | Boundary                     | Rule                                                     |
|---|------------------------------|----------------------------------------------------------|
| 1 | Marketplace ↔ church-platform | No shared infra, state, credentials, or CI. Scope segregation is organizational, enforced technically (separate repos, orgs' IAM, separate networks). ONE sanctioned runtime crossing exists: the internal payment API (ADR-0005, `../docs/payment-api-contract.md`) — mTLS-only, PAN-free, and it shares no state, credentials, or CI. |
| 2 | Bare metal ↔ GCP             | Traffic crosses ONLY via the WireGuard mesh. No other route may exist; any new route is a change to this document first. |
| 3 | GKE ↔ internet               | Ingress only through the sanctioned ingress controller; egress only via Cloud NAT. No node-level public IPs (no-public-ips.rego). |
| 4 | Bare metal ↔ internet        | Ingress only through the nginx edge (60-nginx-edge). Backend hosts have no public listeners. |
| 5 | Operator ↔ production        | All writes via reviewed IaC/CI. Break-glass is an audited exception (terraform/README.md), never a workflow. |
| 6 | Secrets ↔ everything          | Secrets exist in Vaultwarden/ansible-vault/runtime env only. Never in git, state, tfvars, images, logs, or issue trackers. |

## What may never leave this repository

- Terraform state (any copy, any excerpt containing resource identifiers
  in bulk) — a leaked state file is an incident (`../docs/runbooks/state-compromise.md`).
- Network topology detail: host names, WireGuard IPs, subnet layout beyond
  what a specific third-party needs contractually.
- Ansible vault files, vault passwords, CMEK references, WG private keys.
- Runbook steps that reduce attack cost (break-glass, unseal, failover
  credentials) — these stay here, never in wiki/chat/email.

## Scope segregation with church-platform

The `jol-m-*` fleet lives in `journeyoflife-org` with scope-segregated
repositories (marketplace) distinct from church-platform infra
(ISO 27001 A.8.13). Cross-scope contributions require explicit approval
from both scopes' owners; shared modules are forked, not symlinked. The
single payment API (ADR-0005) is the only approved interface across this
segregation; any additional cross-scope interface requires an ADR first.

## Violations

Any observed boundary crossing (new route, new egress, unexplained
credential) is treated as potential compromise until explained by an
approved change record. Unexplained = incident (SECURITY.md).
