# modules/networking — RESERVED

VPC module: subnets, Cloud NAT, firewall, Private Google Access.
Lands with the GCP workstream.

Non-negotiables when implemented:

- Default-deny ingress firewall rules; allow-list per service pair
  (mirrors `../../security/network-policy.md` matrices)
- Private Google Access on all subnets; no public subnets
- Cloud NAT with static egress IPs where third parties need allow-listing
- Flow logs enabled for forensic readiness (ISO 27001 A.8.16)

Do not add `.tf` files here until the workstream has an approved ADR/change
request — empty module directories are intentional.
