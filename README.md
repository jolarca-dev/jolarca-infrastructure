# jol-m-infrastructure — The Marketplace Moat

**Private** infrastructure-as-code repository for the Journey of Life marketplace
scope (`jol-m-*` repository fleet). Scope-segregated from church-platform
infrastructure per ISO 27001:2022 A.5.2 / A.8.13.

> **Access rule:** operators only. Nothing in this repository may be copied,
> quoted, or mirrored into any public repository. See
> [security/isolation-model.md](security/isolation-model.md).

## What this repository is

The 90/10 "Moat" topology:

- **90% bare metal** — hardened hosts, PostgreSQL, Vault, MinIO, backups,
  edge TLS. Managed by **Ansible** (workstream pending — see `ansible/README.md`).
- **10% GCP** — GKE, networking, IAM, DNS. Managed by **Terraform**
  (`terraform/`), with per-environment isolated state.
- **The only bridge** between the two planes is a WireGuard mesh.

Currently landed: the Terraform GitHub-org baseline (repository fleet,
branch protection, org health files). All other workstreams are scaffolded
as reserved structure and land as their workstreams start.

## Quickstart (operators)

```bash
cp .envrc.example .envrc      # then edit; NEVER commit real values
make fmt lint check           # local hygiene before any PR
make plan                     # terraform plan for production (read-only)
```

Terraform runs use `GITHUB_TOKEN` / `GH_TOKEN` from the operator environment
(fine-grained PAT, least scope). Tokens never appear in tfvars, state, or CI logs.

## Compliance posture

| Standard   | Anchor controls covered here                                  |
|------------|---------------------------------------------------------------|
| SOC 2      | CC6.1 logical access, CC6.6 secrets, CC8.1 change management  |
| ISO 27001  | A.5.15 access control, A.8.13 segregation, A.8.24 secure SDLC |
| GDPR       | Art. 25 data protection by design; Art. 32 security of processing (DPIA template in `docs/`) |

Evidence artifacts (access reviews, restore drills, change records) live in
`jol-m-compliance`; this repository produces them, it does not store audit
records containing personal data.

## Repository map

| Path          | Purpose                                                        |
|---------------|----------------------------------------------------------------|
| `terraform/`  | GCP + GitHub-org IaC, backends, OPA policies                    |
| `ansible/`    | Bare-metal plane (reserved; workstream pending)                 |
| `kubernetes/` | GKE workloads, Helm, Kustomize (reserved)                       |
| `backup/`     | Borg config, state backup procedure, restore drills             |
| `monitoring/` | Prometheus / Alertmanager / Grafana as code (reserved)          |
| `security/`   | Isolation doctrine, network policy, key custody, PCI scope      |
| `docs/`       | Architecture, ADRs, runbooks, threat model, DPIA template       |
| `scripts/`    | Bootstrap, rotation, drift, secret-audit helpers                |

## Change discipline

Plan-first. Every change ships with risk class, blast radius, and rollback
plan (see [CONTRIBUTING.md](CONTRIBUTING.md)). Production changes require
review per CODEOWNERS; security-sensitive paths additionally require the
two-person rule enforced through branch protection.
