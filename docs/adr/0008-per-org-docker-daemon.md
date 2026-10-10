# ADR-0008: Per-org Docker daemon for marketplace scope

- **Status:** Proposed (pending operator acceptance + maintenance window)
- **Date:** 2026-10-10
- **Deciders:** org owner (solo era)
- **Compliance:** ISO 27001 A.8.13 · PCI-DSS Req 1/2/3 scope containment · GDPR Art. 32

## Context

The marketplace production stack (`jol-marketplace-prod-*`) runs on the **same
Docker daemon** as church/host services (`jol-vaultwarden` — the master-password
store, `jol-prometheus`, `terraform-mcp`). That daemon's data-root is
`/opt/jol/data/docker` on `nvme0n1p9` — the **journeyoflife-org (church) disk**.
Consequence: cardholder-adjacent volumes (`pgdata`, `esdata`, `redisdata`)
physically reside inside the mission-org tree and disk, while marketplace *code*
was already relocated to `lv_jolarca` (nvme2n1). This contradicts ADR-0004
(separation is "a compliance boundary violation, not a style preference").

Constraints verified 2026-10-10:
- The single data-root is multi-tenant, so moving the whole data-root into
  `/opt/jolarca` would pull church secrets into the PCI tree — the inverse
  commingling. A path change alone cannot fix scope.
- `vgopt` reports `Free PE/Size 0/0` — no new LV can be carved without shrinking
  the live `lv_jolarca`. But `lv_jolarca` is 179 G with only 6.4 G used
  (**173 G free**), ample for a marketplace data-root.
- Bridge subnets `172.17.0.0/16`–`172.21.0.0/16` are in use; a second daemon
  must take a disjoint pool (`172.30.0.0/16`).

## Decision

We will run a **dedicated `dockerd` instance for the marketplace**, isolated from
the church/host daemon:

- New unit `docker-jolarca.service` with `--data-root=/opt/jolarca/data/docker`,
  its own socket `/run/docker-jolarca/docker.sock`, own containerd socket, and
  bridge `docker-jolarca0` on `--bip=172.30.0.0/16` (pool `172.30.0.0/16,size:24`).
- Church + host services (`vaultwarden`, `prometheus`, `terraform-mcp`) remain on
  the existing `docker.service`; nothing about them moves.
- Marketplace named volumes migrate to the new daemon by **logical restore from
  the verified nightly dumps** (postgres `pg_dump`, redis `dump.rdb`), not raw
  volume copy — lower risk and reuses the backup path already hardened in this
  cycle (owner-only `umask 077`). Elasticsearch is unwired (search is
  Postgres-backed) → re-snapshot or rebuild, no app data at risk.
- The compose project is renamed `jol-marketplace-prod` → `jolarca-marketplace-prod`
  in the same window, which also clears the stale pre-rename `/opt/jol-m` working_dir
  labels (closes finding D-04).
- Execution is a **maintenance window** (marketplace down ~10–15 min); old volumes
  and the pre-cutover daemon state are retained until post-acceptance, giving a
  cheap rollback (repoint `DOCKER_HOST` + `up` under the old project name).

## Consequences

- (+) Cardholder-data volumes leave the journeyoflife-org disk; marketplace
  runtime is scope-separated by construction (ISO 27001 A.8.13), provable to an
  auditor via `docker -H unix:///run/docker-jolarca/docker.sock info`.
- (+) Church secrets (Vaultwarden) stay out of the PCI tree — no inverse leak.
- (+) No destructive LVM operation; reuses existing `lv_jolarca` free space.
- (−) Two daemons on one host = more moving parts (extra systemd unit, distinct
  subnets, per-daemon disk/log growth). Mitigated by the mount-guard cron and a
  runbook entry.
- (−) Requires downtime for the cut-over. Mitigated by retained old volumes.
- (−) **Residual:** `lv_jolarca` and `lv_viavitae` share one physical disk
  (nvme2n1) — marketplace and Via-Vitae are LV-separated but **not separate
  failure domains**. Physical-disk isolation is out of scope here.
- (−) Alternative **C (documented risk acceptance, no window)** was considered and
  set aside by the operator in favour of true separation; C remains the fallback
  if the window cannot be scheduled.

## Related

- ADR-0004 mission/marketplace separation (this closes the *runtime-data* gap it
  opened); ADR-0006 redis co-located on app host; ADR-0007 deployment model
  reconciliation; ADR-0002 state isolation design.
- Findings D-03 (data-root in church tree) and D-04 (compose project name/labels).
