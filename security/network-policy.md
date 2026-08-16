# Network policy — default-deny matrices

**Doctrine:** deny all, allow by named exception. Every row below must map
to an implemented rule (nftables / GCP firewall / Kubernetes NetworkPolicy)
when the corresponding workstream lands. Unimplemented rows are the
workstream's acceptance criteria.

## Principle

1. Default-deny inbound on every plane.
2. Allows are expressed as (source, destination, port/protocol, purpose).
3. Purpose must reference a system, not a person ("for jol" is rejected).
4. Each allow expires into review quarterly (`access-review.md`).

## Matrix — bare metal ↔ bare metal

| Source        | Destination      | Port/proto   | Purpose                          |
|---------------|------------------|--------------|----------------------------------|
| all nodes     | all nodes        | 51820/udp    | WireGuard mesh (the bridge fabric)|
| app nodes     | db-primary       | 5432/tcp     | PostgreSQL (TLS-only)            |
| app nodes     | db-replica       | 5432/tcp     | read replicas (TLS-only)         |
| db-*          | db-*             | 5432/tcp     | streaming replication            |
| all nodes     | vault nodes      | 8200/tcp     | secret retrieval (TLS-only)      |
| all nodes     | minio nodes      | 9000/tcp     | object storage API               |
| edge node     | app nodes        | 8080/tcp     | reverse proxy upstreams          |
| monitoring    | all nodes        | 9100/tcp     | node_exporter scrape             |
| bastion       | all nodes        | 22/tcp       | operator SSH (key+MFA only)      |

## Matrix — bare metal ↔ GCP

| Source              | Destination        | Port/proto | Purpose                        |
|---------------------|--------------------|------------|--------------------------------|
| WG gateway (metal)  | GKE WG peer        | 51820/udp  | the ONLY bridge between planes |
| GKE ingress         | edge node (metal)  | 443/tcp    | failover path ONLY if approved |

Any additional metal↔GCP flow requires an update to this document and to
`isolation-model.md` boundary 2 BEFORE implementation.

## Matrix — GKE ↔ internet

| Direction | Mechanism                | Rule                              |
|-----------|--------------------------|-----------------------------------|
| Ingress   | ingress controller + WAF | 443 only; rate limits enforced    |
| Egress    | Cloud NAT                | Allow-list third-party endpoints  |
| Node IPs  | —                        | NEVER public (no-public-ips.rego) |

## Matrix — payment boundary (ADR-0005; future workstream)

Model A keeps jol-hub out of PCI scope: ONLY `payments_app` may reach
Stripe, and the payment API is the single sanctioned cross-program flow
(ADR-0004 Amendment 1). Unimplemented rows are the payment-boundary
workstream's acceptance criteria (same rule as above).

| Source                          | Destination                          | Port/proto | Purpose                                              |
|---------------------------------|--------------------------------------|------------|------------------------------------------------------|
| payments_app (CDE segment)      | api.stripe.com                       | 443/tcp    | the ONLY sanctioned Stripe egress (Cloud NAT allow-list) |
| jol-hub workloads               | payment service internal endpoint    | 443/tcp    | payment API (mTLS; `docs/payment-api-contract.md`)   |
| payments_app webhook forwarder  | jol-hub internal webhook endpoint    | 443/tcp    | signed per-product events (`X-Product: hub`)         |
| jol-hub workloads               | api.stripe.com                       | —          | **DENIED by absence**: no allow row may ever be added without a new ADR (ADR-0005 E3) |

## Enforcement mapping

| Plane      | Enforcement point                                  |
|------------|----------------------------------------------------|
| bare metal | nftables via `ansible/roles/common` (default-deny) |
| GCP        | VPC firewall via `terraform/modules/networking`    |
| GKE        | NetworkPolicy via `kubernetes/base` + Kyverno      |
