# Jolarca Infrastructure — Documentation

> **The Marketplace Moat** — 90% bare metal, 10% GCP, connected by WireGuard mesh.

## Architecture

| Document | Description |
|----------|-------------|
| [Architecture Overview](architecture.md) | System topology, 90/10 split, deployment model |
| [Threat Model](threat-model.md) | STRAN analysis, trust boundaries, mitigations |
| [Payment Boundary Enforcement](payment-boundary-enforcement.md) | PCI-DSS scope isolation design |
| [Payment API Contract](payment-api-contract.md) | Internal payment boundary API specification |
| [Workload Identity Federation](workload-identity-federation.md) | GCP workload identity configuration |

## Architecture Decision Records (ADRs)

| ADR | Title | Status |
|-----|-------|--------|
| [ADR-0001](adr/0001-90-10-split-rationale.md) | 90/10 Bare Metal / Cloud Split Rationale | Accepted |
| [ADR-0002](adr/0002-state-isolation-design.md) | State Isolation Design | Accepted |
| [ADR-0003](adr/0003-encrypted-remote-state-migration.md) | Encrypted Remote State Migration | Accepted |
| [ADR-0004](adr/0004-mission-marketplace-separation.md) | Mission / Marketplace Separation | Accepted |
| [ADR-0005](adr/0005-single-payment-boundary.md) | Single Payment Boundary | Accepted |

## Runbooks

| Runbook | Description |
|---------|-------------|
| [Bootstrap from Zero](runbooks/bootstrap-from-zero.md) | Full environment bootstrap procedure |
| [Bootstrap State Backend](runbooks/bootstrap-state-backend.md) | Terraform state backend setup |
| [GitHub Token Rotation](runbooks/github-token-rotation.md) | PAT rotation procedure |
| [PostgreSQL Failover](runbooks/postgres-failover.md) | Database failover procedure |
| [State Compromise](runbooks/state-compromise.md) | Terraform state compromise response |
| [Vault Sealed](runbooks/vault-sealed.md) | Vault unseal procedure |
| [WireGuard Key Rotation](runbooks/wireguard-key-rotation.md) | WireGuard key rotation |

## Security

| Document | Description |
|----------|-------------|
| [Isolation Model](../security/isolation-model.md) | Network and data isolation doctrine |
| [Network Policy](../security/network-policy.md) | Network segmentation rules |
| [Key Custody](../security/key-custody.md) | Encryption key management |
| [CIS Baseline](../security/cis-baseline.md) | CIS benchmark alignment |
| [Access Review](../security/access-review.md) | Access review procedure |
| [PCI-DSS Scope](../security/pci-dss-scope.md) | PCI-DSS scope statement |

## Compliance

| Standard | Anchor |
|----------|--------|
| SOC 2 | CC6.1, CC6.6, CC7.2, CC8.1 |
| ISO 27001:2022 | A.5–A.18 controls |
| GDPR | Art. 25, 32 |
| PCI-DSS | SAQ-A (Stripe-hosted) |

---

[← Back to Repository](../) | [Organization](https://github.com/jolarca-dev)
