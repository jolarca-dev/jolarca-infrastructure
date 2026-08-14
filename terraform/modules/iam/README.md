# modules/iam — RESERVED

Least-privilege service accounts and bindings. Lands with the GCP workstream.

Non-negotiables when implemented:

- One purpose-bound service account per workload; no shared "utility" SAs
- Basic roles (owner/editor/viewer) BANNED — enforced by
  `../policies/no-basic-iam-roles.rego`
- Curated per-service roles only; condition bindings where supported
- No long-lived keys: Workload Identity Federation for GKE, short-lived
  credentials elsewhere (see `../../security/key-custody.md`)

Do not add `.tf` files here until the workstream has an approved ADR/change
request — empty module directories are intentional.
