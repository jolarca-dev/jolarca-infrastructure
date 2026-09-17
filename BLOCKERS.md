# BLOCKERS — jolarca-marketplace deployment

**Date:** 2026-09-10 (updated from 2026-09-02)  
**Context:** Proxmox hardware pending delivery. All Ansible roles and playbooks are now implemented.  
**Rule:** Every gap between current state and deployment gate, with owner + effort estimate.

---

## Resolved Since Last Assessment (2026-09-02 → 2026-09-09)

The following blockers from the original assessment are now **RESOLVED at the code level**.
They remain untestable until Proxmox hardware is provisioned, but no further development
work is required.

| ID | Original Blocker | Resolution Evidence |
|----|-----------------|---------------------|
| B1 | Ansible roles are empty scaffolds | All 10 roles implemented (47–255 lines each); 11 playbooks exist |
| B2 | Backups not implemented | `80-backup.yml` + backup role (255 lines): pg_dump, WAL archive, MinIO, Vault snapshot, BorgBackup |
| B5 | No TLS / nginx edge | `70-nginx-edge.yml` + `90-nginx-hardening.yml` + nginx role (71 lines) |
| B6 | No WireGuard playbook | `10-wireguard.yml` + wireguard role (54 lines) |
| B7 | No Vault bootstrap code | `30-vault.yml` + vault role (104 lines): install, TLS, Raft, systemd, health check |
| B10 | Monitoring/alerting not implemented | `95-monitoring.yml` + monitoring role (194 lines) + real configs in `monitoring/` |
| B11 | Incident runbook not executable | `docs/incident-runbook.md` (291 lines): 5 failure modes with step-by-step procedures |
| B14 | PostgreSQL version inconsistency | App repo updated to PG 17 (`postgis/postgis:17-3.5`, `postgres:17-alpine`, `postgresql-17-pgvector`) across all 3 Docker artifacts |
| B15 | Deployment model unreconciled | ADR-0007 accepted; `app_deploy_mode` variable implemented with `compose-monolith` + `compose-split` paths; handlers and templates mode-aware |

### Implemented role inventory (verified 2026-09-09)

| Role | Lines | Playbook | Status |
|------|-------|----------|--------|
| hardening | 242 | `00-hardening.yml` | ✅ Complete |
| wireguard | 54 | `10-wireguard.yml` | ✅ Complete |
| vault | 104 | `30-vault.yml` | ✅ Complete |
| postgresql | 109 | `40-postgresql.yml` | ✅ Complete |
| redis | 47 | `45-redis.yml` | ✅ Complete |
| minio | 74 | `50-minio.yml` | ✅ Complete |
| app | 313 | `65-app.yml` | ✅ Complete |
| nginx | 71 | `70-nginx-edge.yml` | ✅ Complete |
| backup | 255 | `80-backup.yml` | ✅ Complete |
| monitoring | 194 | `95-monitoring.yml` | ✅ Complete |
| — | 188 | `90-nginx-hardening.yml` | ✅ Complete |

---

## Active Critical Blockers (must resolve before production)

### B3: Restore drill never executed

| Field | Value |
|-------|-------|
| **Severity** | Critical |
| **Blocks** | Production |
| **Owner** | Infrastructure engineer + DPO (witness) |
| **Effort** | 2 days |
| **Current state** | `backup/restore-drill.md` documents the procedure. Backup role + playbook implemented. No hardware to execute against. |
| **Required state** | Drill executed; RTO ≤ 4h verified; RPO ≤ 15min verified; timestamped evidence in compliance repo |
| **Prerequisite** | Proxmox hardware provisioned + backup LXC running |
| **Risk if skipped** | Untested backups are no backups; audit failure |

**Plan:**
1. Execute drill per `backup/restore-drill.md` — 1 day
2. Record results (pass/fail per step, timing) — 0.5 days
3. Commit evidence to `jolarca-compliance/audits/restore-drills/` — 0.5 days

---

### B4: DPIA-003 unsigned

| Field | Value |
|-------|-------|
| **Severity** | Critical |
| **Blocks** | Production |
| **Owner** | DPO (Data Protection Officer) |
| **Effort** | 1–2 weeks (depends on DPO availability) |
| **Current state** | `dpia/003-payments-and-vat/` is a draft skeleton. G3 gate WITHHELD. |
| **Required state** | DPIA-003 completed, signed by DPO, hash committed to compliance repo |
| **Risk if skipped** | GDPR Art. 35 violation; fine up to €10M or 2% global turnover |

**Plan:**
1. Complete DPIA-003 assessment (payments + VAT data flows) — 5 days
2. DPO review and signature — 3–5 days
3. Compute hash; commit to compliance repo — 0.5 days

---

### B13: Proxmox hardware not provisioned (NEW)

| Field | Value |
|-------|-------|
| **Severity** | Critical |
| **Blocks** | ALL deployment (staging AND production) |
| **Owner** | Infrastructure engineer |
| **Effort** | 3 days (once hardware arrives) |
| **Current state** | All Ansible code is ready. No physical host. All `ansible_host` entries in inventories are commented out. |
| **Required state** | Proxmox VE installed, hardened, VMs/LXCs created, WireGuard mesh up, Vault unsealed |
| **Evidence** | `ansible/inventories/staging/hosts.yml` — all IPs commented |
| **Risk if skipped** | Nothing can be deployed, tested, or drilled |

**Plan (once hardware arrives):**
1. Install Proxmox VE + CIS hardening — Day 1
2. Create VMs/LXCs per `PROXMOX_DEPLOYMENT_PLAN.md` — Day 1–2
3. Run `00-hardening.yml` + `10-wireguard.yml` — Day 2
4. Run `30-vault.yml` + unseal ceremony — Day 2
5. Run `40-postgresql.yml` + `45-redis.yml` + `50-minio.yml` — Day 3
6. Run `65-app.yml` + `70-nginx-edge.yml` — Day 3
7. Run `80-backup.yml` + `95-monitoring.yml` — Day 3
8. Execute smoke tests (`scripts/smoke-test-staging.sh`) — Day 3

---

## High Blockers (block unless risk-accepted)

### B8: VIES not wired to live gateway

| Field | Value |
|-------|-------|
| **Severity** | High |
| **Blocks** | Production (B2B sales) |
| **Owner** | Backend engineer |
| **Effort** | 3–5 days |
| **Current state** | Format-only validation; `vies_checked: false`; honest contract |
| **Required state** | Live VIES SOAP client; VAT ID validity confirmed against EU gateway |
| **Risk if skipped** | B2B VAT validation not enforced; LT tax authority finding |

---

### B9: CodeQL/SAST disabled

| Field | Value |
|-------|-------|
| **Severity** | High |
| **Blocks** | Production (risk-accept for staging) |
| **Owner** | Security engineer |
| **Effort** | 2 days |
| **Current state** | `codeql.yml.disabled` in 4/5 repos. No SAST scanning. |
| **Required state** | CodeQL or Semgrep enabled in all repos; results reviewed |
| **Risk if skipped** | Vulnerabilities undetected; SOC 2 CC7.1 gap |

---

### B12: OSS registration incomplete

| Field | Value |
|-------|-------|
| **Severity** | Medium-High |
| **Blocks** | Production (B2C cross-border EU sales) |
| **Owner** | Legal/finance |
| **Effort** | 1–2 weeks (depends on VMI processing) |
| **Current state** | Directory exists. No filing evidence. |
| **Required state** | OSS registration completed with VMI; quarterly filing mechanism |
| **Risk if skipped** | VAT non-compliance for cross-border B2C |

---

## Effort Summary (Updated 2026-09-10)

| Category | Critical | High | Total | Status |
|----------|----------|------|-------|--------|
| Infrastructure code (Ansible roles, playbooks) | 0 | 0 | 0 | ✅ ALL RESOLVED |
| Hardware provisioning (Proxmox) | 1 | 0 | 1 | ❌ Pending delivery |
| Deployment model reconciliation | 0 | 0 | 0 | ✅ RESOLVED (ADR-0007 + app_deploy_mode) |
| Data (restore drill) | 1 | 0 | 1 | ❌ Needs hardware |
| Compliance (DPIA) | 1 | 0 | 1 | ❌ Needs DPO |
| Application (VIES, CodeQL) | 0 | 2 | 2 | ❌ Needs dev work |
| Legal/finance (OSS) | 0 | 1 | 1 | ❌ Needs VMI |
| **Total active** | **3** | **3** | **6** | — |

### Estimated timeline (from hardware arrival)

| Phase | Duration | Prerequisites |
|-------|----------|---------------|
| Proxmox install + VM/LXC creation | 1 day | Hardware delivered |
| Run all Ansible playbooks (00→95) | 1 day | VMs created |
| Vault unseal ceremony + secrets population | 0.5 day | Vault VM running |
| Smoke tests + staging green | 0.5 day | All playbooks pass |
| 7-day staging soak | 7 days | Staging green |
| Restore drill | 1 day | Backup running |
| DPIA-003 signature | 1–2 weeks | DPO available (parallel) |
| VIES live wiring | 3–5 days | Backend engineer (parallel) |
| CodeQL/SAST enablement | 2 days | Security engineer (parallel) |
| Production cutover | 1 day | All above complete |
| **Total to production-ready** | **3–4 weeks** | Hardware + parallel workstreams |

### 3-day milestone (now achievable)

```
Day 1: Proxmox arrives → install + harden host + create VMs/LXCs
Day 2: Run playbooks 00→50 (hardening, WireGuard, Vault, PostgreSQL, Redis, MinIO)
Day 3: Run playbooks 65→95 (app, nginx, backup, monitoring) → smoke tests
```

**This gets you a staging environment. NOT production.**

All Ansible code is ready. The 3-day milestone is achievable on hardware arrival
with zero additional development work.
