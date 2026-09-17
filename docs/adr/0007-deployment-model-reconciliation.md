# ADR-0007: Deployment Model Reconciliation — Pilot vs. Target

**Status:** Accepted
**Date:** 2026-09-09
**Deciders:** Infrastructure Lead (sole operator, solo era)

## Context

Two deployment models exist in parallel across the fleet, creating
ambiguity about which is authoritative:

**Model A — App-repo monolithic compose** (`jolarca/docker-compose.prod.yml`):
All 8 services (nginx, app/frontend, backend, worker, beat, postgres, redis,
elasticsearch) run as containers on a single VM. Deployed via
`scripts/deploy.sh`. Self-contained: the compose file IS the topology.

**Model B — Infra-repo distributed Ansible** (`jolarca-infrastructure/ansible/`):
Services are distributed across 7 VMs/LXCs (edge, app, db, vault, minio,
monitor, backup). Each tier has its own Ansible role. The app role renders
separate `docker-compose.backend.yml` and `docker-compose.frontend.yml`
templates. PostgreSQL runs natively (not containerized) on the DB VM.

These models are architecturally incompatible:
- Model A co-locates PostgreSQL in a container on the app host; Model B
  provisions PostgreSQL natively on a dedicated DB VM.
- Model A uses Docker networks (`frontend`, `backend`) for isolation;
  Model B uses WireGuard mesh between VMs.
- Model A has no Vault VM (secrets via `.env.prod` file); Model B has a
  dedicated Vault VM with HashiCorp Vault.
- Model A includes Elasticsearch as a service; Model B has no Elasticsearch
  role (it would run inside the app compose stack).

## Decision

**Both models are retained, scoped to distinct lifecycle phases:**

| Phase | Model | Scope | When |
|-------|-------|-------|------|
| Lithuania Pilot | Model A (compose) | Single App VM runs the full stack | Day 1–90 |
| Production Target | Model B (Ansible) | Multi-VM distributed topology | Post-pilot scale |

### Pilot deployment (Model A):

1. The Proxmox host creates VMs per `PROXMOX_DEPLOYMENT_PLAN.md` (all 7).
2. Infrastructure Ansible playbooks run on ALL VMs: hardening (00),
   WireGuard (10), Vault (30), monitoring (95), backup (80).
3. The **App VM (101)** runs `docker-compose.prod.yml` from the `jolarca`
   repo as the application stack — including its own postgres, redis, and
   elasticsearch containers.
4. The **DB VM (102)**, **MinIO LXC (200)** are provisioned by Ansible
   (playbooks 40, 50) but remain **standby** during the pilot — they are
   the migration target for Phase 2.
5. Secrets flow: HashiCorp Vault (VM 103) → `.env.prod` on App VM
   (rendered by Ansible `app` role from Vault KV, permissions 0640,
   never committed to Git).

### Production target (Model B):

Once the pilot proves stable and traffic demands scale:
1. Migrate PostgreSQL from the compose container to the dedicated DB VM
   (already provisioned by playbook 40).
2. Migrate Redis to the App VM native install (ADR-0006, playbook 45).
3. Migrate MinIO to the dedicated LXC (already provisioned by playbook 50).
4. Remove the postgres/redis/elasticsearch services from the compose file.
5. The app role's split compose templates (`docker-compose.backend.yml`,
   `docker-compose.frontend.yml`) become authoritative.

### Migration trigger:

Move from Model A → Model B when ANY of:
- PostgreSQL data exceeds 50 GB (container volume performance)
- Redis memory exceeds 200 MB consistently (ADR-0006 review threshold)
- More than 1 App VM is needed (horizontal scaling)
- Backup/restore drill shows container-based PG recovery is unreliable

## Alternatives considered

- **Model A only (permanent):** Rejected — single-VM blast radius,
  no Vault integration for runtime secrets, no dedicated backup host,
  violates the isolation model's network segmentation intent at scale.
- **Model B only (from Day 1):** Rejected — over-engineered for a pilot
  with zero traffic. Requires reconciling the app repo's Dockerfile and
  compose assumptions before any deployment can happen. Delays time-to-staging.
- **Hybrid from Day 1 (Model A app + Model B data):** Considered but
  rejected for pilot — adds WireGuard latency between app containers and
  external DB, complicates the compose healthchecks, and creates a partial
  migration state that is harder to debug than either pure model.

## Consequences

### Positive
- (+) Pilot can deploy in 3 days once hardware arrives (zero code changes needed)
- (+) `scripts/deploy.sh` works as-is for the pilot
- (+) All 7 VMs are provisioned from Day 1 — the migration path is pre-built
- (+) Vault is operational from Day 1 even though the compose file uses `.env.prod`

### Negative
- (−) During pilot, PostgreSQL runs in a container (not the hardened native
  install on DB VM) — accepted risk for a zero-traffic staging soak
- (−) Two compose file sets exist in the infra repo templates — the pilot
  ignores them until Model B migration
- (−) `.env.prod` exists as plaintext on the App VM disk (permissions 0640,
  rendered from Vault by Ansible, never in Git) — accepted as a runtime
  derivative per the same pattern as `ansible-vault` transport files

### Neutral
- The `docker-compose.prod.yml` in the app repo is the pilot's source of truth
- The Ansible `app` role templates are the target's source of truth
- Both are maintained; neither is deprecated

## Compliance mapping

- ISO 27001 A.8.13 (segregation): Pilot accepts co-location; target state
  enforces VM-level isolation. Deviation logged and time-bounded.
- SOC 2 CC6.1 (logical access): Vault controls secret access in both models.
- GDPR Art. 32 (security): `.env.prod` is 0640, rendered from Vault, never
  committed. Container isolation provides process-level separation.

## Implementation checklist

- [x] Update `ansible/roles/app/tasks/main.yml` to support a `app_deploy_mode`
      variable: `compose-monolith` (pilot) vs `compose-split` (target)
- [x] In pilot mode, the app role clones the `jolarca` repo and runs
      `docker compose -f docker-compose.prod.yml up -d` instead of rendering
      separate templates
- [x] Ensure `.env.prod` is rendered from Vault KV by the `app.env.j2` template
      with mode 0640 and `no_log: true`
- [ ] Document the Model A → Model B migration runbook in
      `docs/runbooks/pilot-to-production-migration.md`
