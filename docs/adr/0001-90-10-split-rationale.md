# ADR-0001: 90/10 split — bare metal primary, GCP secondary

- **Status:** Accepted
- **Date:** 2026-08-14
- **Deciders:** infra operators (names in compliance record)

## Context

The marketplace requires EU data residency, payment-grade isolation, and
cost-predictable capacity for the data plane, while still needing managed
cloud capabilities (autoscaling, GPU inference) for a minority of
workloads.

## Decision

Run ~90% of the platform on owned/leased bare metal (Ansible-managed),
~10% on GCP (Terraform-managed: GKE, networking, IAM, DNS), bridged
exclusively by a WireGuard mesh.

## Consequences

- (+) Data plane stays under direct custody; residency provable.
- (+) Cloud bill limited to elastic/GPU workloads.
- (−) We own hardening, replication, backup operations — codified as
  playbooks + drills, not tribal knowledge.
- (−) One bridge = one choke point: monitored (WG handshake age alert)
  and key-rotated (`docs/runbooks/wireguard-key-rotation.md`).

## Compliance mapping

ISO 27001 A.8.13 (segregation by construction), GDPR Art. 32 (control
over processing infrastructure), PCI-DSS scope containment
(`security/pci-dss-scope.md`).
