# modules/gke — RESERVED

GKE cluster module for the 10% GCP plane. Lands with the GCP workstream.

Non-negotiables when implemented:

- Private nodes (no public IPs — enforced by `../policies/no-public-ips.rego`)
- Workload Identity enabled; default compute service account DISABLED
- Network policy (or Dataplane V2 policy) with default-deny
- Release channel pinned; upgrades soak in staging first
- `database_encryption` for application-layer secrets (require-cmek.rego)

Do not add `.tf` files here until the workstream has an approved ADR/change
request — empty module directories are intentional.
