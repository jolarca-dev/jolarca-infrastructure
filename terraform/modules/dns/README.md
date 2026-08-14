# modules/dns — RESERVED

Cloud DNS zones and records. Lands with the GCP workstream.

Non-negotiables when implemented:

- DNSSEC enabled on all public zones
- Private zones for internal service discovery (never exposed publicly)
- Record changes are plan-first like every other resource
- No record pointing at bare-metal internals from public zones

Do not add `.tf` files here until the workstream has an approved ADR/change
request — empty module directories are intentional.
