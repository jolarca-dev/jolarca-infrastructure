# modules/state-bucket — RESERVED

Bootstrapping module: provisions the Terraform state buckets themselves.
Lands with the state-migration workstream (ADR-0003, terraform/README.md).

Non-negotiables when implemented:

- One bucket per environment; bucket names globally unique and documented
- CMEK encryption with an environment-specific key (require-cmek.rego)
- Object versioning + retention policy; uniform bucket-level access
- Admin/data-read audit logging to the compliance log sink
- A dedicated service account per bucket; no human members
- `lifecycle { prevent_destroy = true }` on the bucket

Bootstrap ordering problem: this module's own state must be bootstrapped
manually once (documented in terraform/README.md), then self-managed.

Do not add `.tf` files here until the workstream has an approved ADR/change
request — empty module directories are intentional.
