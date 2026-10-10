# ADR-0008: Per-org Docker daemon for marketplace scope

- **Status:** Proposed (pending operator acceptance + maintenance window)
- **Date:** 2026-10-10
- **Deciders:** org owner (solo era)
- **Compliance:** ISO 27001 A.8.13 · PCI-DSS Req 1/2/3 scope containment · GDPR Art. 32
- **Amendment (2026-10-10, post-Phase-1):** migration method corrected from
  logical-restore to **physical volume copy** (initdb/AOF evidence below); network
  and containerd details corrected to match the deployed `docker-jolarca.service`.

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
  must draw its compose networks from a **disjoint** address pool.

## Decision

We will run a **dedicated `dockerd` instance for the marketplace**, isolated from
the church/host daemon:

- Unit `docker-jolarca.service` with `--data-root=/opt/jolarca/data/docker` (on
  `lv_jolarca`) and its own socket `/run/docker-jolarca/docker.sock`. Because the
  default pidfile `/var/run/docker.pid` and exec-root `/run/docker` collide with
  the running church daemon, it overrides `--pidfile` and `--exec-root` under
  `/run/docker-jolarca`.
- **Dedicated containerd** (`docker-jolarca-containerd.service`, socket
  `/run/docker-jolarca/containerd.sock`, content store `/opt/jolarca/data/containerd`).
  Omitting `--containerd` would silently share the system containerd's `moby`
  namespace and cross-see the church containers, so the second daemon must have
  its own. Network: `bridge: none` and `default-address-pools` base
  `172.31.0.0/16,size:24` (a named `-b` bridge plus `--bip` is a mutually-exclusive
  error, and the marketplace only uses compose-created `frontend`/`backend` networks).
- `RequiresMountsFor=/opt/jolarca` so the enabled boot-time units wait on the PCI
  mount instead of creating dirs on `/`.
- Church + host services (`vaultwarden`, `prometheus`, `terraform-mcp`) remain on
  the existing `docker.service`; nothing about them moves.
- Marketplace data migrates by **physical volume copy**, not logical restore.
  Evidence that the logical plan was unsafe: (1) the `jol-marketplace/postgres:
  16-postgis` image runs `/docker-entrypoint-initdb.d/` scripts (`00-extensions.sql`,
  `10_postgis.sh`) on an *empty* first-boot volume, so a schema-inclusive `pg_dump`
  restore collides with pre-created postgis/tiger objects; (2) redis runs with
  `--appendonly yes`, so a copied `dump.rdb` is ignored in favour of the AOF; and
  (3) the nightly 03:00 dump would lose all daytime writes. Instead: `compose down`
  (clean stop → consistent on-disk state), `rsync -aHAX` each named volume's `_data`
  from the church data-root to the pre-created PCI volume (via `pkexec`, since the
  church data-root is root-only), then `up` — postgres sees a populated PGDATA and
  skips initdb, redis loads its AOF, ES data copies intact. Images move via
  `docker save`/`load`. Elasticsearch is unwired (search is Postgres-backed) but is
  still copied for consistency.
- The compose project is renamed `jol-marketplace-prod` → `jolarca-marketplace-prod`
  in the same window, which also clears the stale pre-rename `/opt/jol-m` working_dir
  labels (closes finding D-04). Crontab marketplace jobs are repointed via a global
  `DOCKER_HOST=unix:///run/docker-jolarca/docker.sock` env line.
- Execution is a **maintenance window** (marketplace down ~2–10 min); old volumes
  and images are retained until post-acceptance, giving a cheap rollback
  (re-up under the old project name on the church daemon). A guarded `migrate.sh`
  (`preflight|run|verify|rollback`) enforces a table-agnostic row+table fingerprint
  match (`rows=8957 tables=39` at draft) before repointing automation.

## Consequences

- (+) Cardholder-data volumes leave the journeyoflife-org disk; marketplace
  runtime is scope-separated by construction (ISO 27001 A.8.13), provable to an
  auditor via `docker -H unix:///run/docker-jolarca/docker.sock info`.
- (+) Church secrets (Vaultwarden) stay out of the PCI tree — no inverse leak.
- (+) No destructive LVM operation; reuses existing `lv_jolarca` free space.
- (+) Physical copy is lossless (captures live state at `down`) and avoids the
  initdb/AOF restore hazards the logical plan would have hit mid-window.
- (−) Two daemons on one host = more moving parts (extra systemd units, a second
  containerd, distinct address pool, per-daemon disk/log growth). Mitigated by the
  mount-guard cron and a runbook entry.
- (−) Volume copy needs root (`pkexec`) to read the church data-root; adds an auth
  prompt inside the window.
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
