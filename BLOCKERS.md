# BLOCKERS — jolarca-marketplace deployment

**Date:** 2026-09-02  
**Context:** Proxmox server arriving in ~3 days  
**Rule:** Every gap between current state and deployment gate, with owner + effort estimate.

---

## Critical Blockers (must resolve before production)

### B1: Ansible roles are empty scaffolds

| Field | Value |
|-------|-------|
| **Severity** | Critical |
| **Blocks** | Production AND staging |
| **Owner** | Infrastructure engineer |
| **Effort** | 2–3 weeks |
| **Current state** | `ansible/roles/` contains only `.gitkeep` files. Zero playbooks. |
| **Required state** | Playbooks for: 00-hardening, 10-wireguard, 20-postgresql, 30-vault, 40-minio, 50-backup, 60-nginx-edge, 70-monitoring, 90-disaster-recovery |
| **Evidence** | `find ansible/roles -type f` returns 0 files |
| **Risk if skipped** | No reproducible deployment; manual config drift; audit failure |

**Plan:**
1. Write `00-hardening.yml` first (CIS baseline for Debian 12) — 3 days
2. Write `10-wireguard.yml` (mesh setup) — 2 days
3. Write `20-postgresql.yml` (PostgreSQL 17 + PostGIS 3.5 + pgcrypto) — 3 days
4. Write `30-vault.yml` (HashiCorp Vault bootstrap) — 2 days
5. Write remaining roles — 5 days
6. Molecule tests for each role — 3 days

---

### B2: Backups not implemented

| Field | Value |
|-------|-------|
| **Severity** | Critical |
| **Blocks** | Production |
| **Owner** | Infrastructure engineer |
| **Effort** | 1 week |
| **Current state** | BorgBackup specification exists (`backup/borg/offsite-repo.md`). No Ansible playbook. No backup job. |
| **Required state** | Automated daily backups (PostgreSQL PITR, MinIO, app config). Encrypted offsite copy. Quarterly restore drill. |
| **Evidence** | `ansible/playbooks/50-backup.yml` does not exist |
| **Risk if skipped** | Data loss; SOC 2 A1.3 failure; ISO 27001 A.5.29 failure; GDPR Art. 32 failure |

**Plan:**
1. Provision offsite Borg repository (Hetzner Storage Box or equivalent) — 1 day
2. Write `50-backup.yml` playbook — 2 days
3. Configure PostgreSQL WAL archiving — 1 day
4. Execute first restore drill — 1 day
5. Document drill results with timestamp — 1 day

---

### B3: Restore drill never executed

| Field | Value |
|-------|-------|
| **Severity** | Critical |
| **Blocks** | Production |
| **Owner** | Infrastructure engineer + DPO (witness) |
| **Effort** | 2 days |
| **Current state** | `backup/restore-drill.md` documents the procedure. No evidence of execution. |
| **Required state** | Drill executed; RTO ≤ 4h verified; RPO ≤ 15min verified; timestamped evidence in compliance repo |
| **Evidence** | No drill log files; no timestamps |
| **Risk if skipped** | Untested backups are no backups; audit failure |

**Plan:**
1. Execute drill per `restore-drill.md` — 1 day
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
| **Evidence** | `audits/gate-evidence/G3-payments/G3_DECISION.md`: "DPIA 003 signed + hash (currently draft skeleton)" — WITHHELD |
| **Risk if skipped** | GDPR Art. 35 violation; fine up to €10M or 2% global turnover; first real donation cannot be authorized |

**Plan:**
1. Complete DPIA-003 assessment (payments + VAT data flows) — 5 days
2. DPO review and signature — 3–5 days
3. Compute hash; commit to compliance repo — 0.5 days
4. Update G3 decision record — 0.5 days

---

### B5: No TLS / nginx edge

| Field | Value |
|-------|-------|
| **Severity** | Critical |
| **Blocks** | Production AND staging |
| **Owner** | Infrastructure engineer |
| **Effort** | 3 days |
| **Current state** | `60-nginx-edge` is "pending" per audit report F-12. No TLS configuration. |
| **Required state** | nginx reverse proxy with TLS 1.3; rate limiting; security headers; Let's Encrypt (or staging ACME) |
| **Evidence** | Audit report: "4. Bare metal ↔ internet via nginx edge only — none yet (60-nginx-edge pending) — NO → F-12" |
| **Risk if skipped** | No encrypted transport; MITM attacks; PCI-DSS failure; GDPR Art. 32 failure |

**Plan:**
1. Write `60-nginx-edge.yml` playbook — 2 days
2. Configure TLS 1.3 (Let's Encrypt staging for staging env) — 0.5 days
3. Rate limiting + security headers — 0.5 days

---

### B6: No WireGuard playbook

| Field | Value |
|-------|-------|
| **Severity** | Critical |
| **Blocks** | Production AND staging |
| **Owner** | Infrastructure engineer |
| **Effort** | 2 days |
| **Current state** | WireGuard documented in architecture.md. Key rotation runbook is "skeleton". No Ansible playbook. |
| **Required state** | `10-wireguard.yml` playbook; mesh configured; keys in Vault |
| **Evidence** | `docs/runbooks/wireguard-key-rotation.md`: "Status: skeleton — lands with the ansible 10-wireguard.yml workstream" |
| **Risk if skipped** | No secure inter-VM communication; isolation model violated |

**Plan:**
1. Write `10-wireguard.yml` playbook — 1.5 days
2. Generate keys; store in Vault — 0.5 days

---

### B7: No Vault bootstrap

| Field | Value |
|-------|-------|
| **Severity** | Critical |
| **Blocks** | Production |
| **Owner** | Infrastructure engineer + security lead |
| **Effort** | 3 days |
| **Current state** | ansible-vault documented for playbook secrets. HashiCorp Vault not bootstrapped. |
| **Required state** | Vault initialized; unseal keys distributed (Shamir); KV v2 enabled; PKI enabled; app secrets stored |
| **Evidence** | No Vault VM configured; no unseal ceremony documented |
| **Risk if skipped** | Runtime secrets in environment variables or files; no audit trail; no auto-rotation |

**Plan:**
1. Write `30-vault.yml` playbook — 1.5 days
2. Conduct unseal ceremony (distribute key shares) — 0.5 days
3. Store app secrets in Vault KV — 1 day

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
| **Evidence** | `apps/tax_app/views.py`: "The live VIES gateway is unwired (MVP-T3)" |
| **Risk if skipped** | B2B VAT validation not enforced; potential VAT fraud exposure; LT tax authority finding |

**Plan:**
1. Implement VIES SOAP client (suds or zeep) — 2 days
2. Add caching (VIES responses valid for 24h) — 0.5 days
3. Update endpoint to return `vies_checked: true` when live — 0.5 days
4. Test against EU test gateway — 1 day

---

### B9: CodeQL/SAST disabled

| Field | Value |
|-------|-------|
| **Severity** | High |
| **Blocks** | Production (risk-accept for staging) |
| **Owner** | Security engineer |
| **Effort** | 2 days |
| **Current state** | `codeql.yml.disabled` in 4/5 repos. No SAST scanning. |
| **Required state** | CodeQL or Semgrep enabled in all repos; results reviewed; no open criticals |
| **Evidence** | `ls .github/workflows/codeql*` returns `.disabled` files |
| **Risk if skipped** | Vulnerabilities in code undetected; SOC 2 CC7.1 gap |

**Plan:**
1. Enable CodeQL (or Semgrep) in all repos — 1 day
2. Review initial findings; fix or risk-accept — 1 day

---

### B10: Monitoring/alerting not implemented

| Field | Value |
|-------|-------|
| **Severity** | High |
| **Blocks** | Production (risk-accept for staging) |
| **Owner** | Infrastructure engineer |
| **Effort** | 3 days |
| **Current state** | `monitoring/` contains only `.gitkeep` files |
| **Required state** | Prometheus + Grafana + Alertmanager deployed; key metrics armed; alerting tested |
| **Evidence** | `find monitoring/ -type f` returns only `.gitkeep` and `README.md` |
| **Risk if skipped** | No visibility into system health; incident detection delayed; SOC 2 CC7.2 gap |

**Plan:**
1. Write `70-monitoring.yml` playbook — 2 days
2. Configure key alerts (disk, memory, CPU, error rate, latency) — 0.5 days
3. Test alerting (trigger + acknowledge + resolve) — 0.5 days

---

### B11: Incident runbook not executable

| Field | Value |
|-------|-------|
| **Severity** | High |
| **Blocks** | Production (risk-accept for staging) |
| **Owner** | Security lead + DPO |
| **Effort** | 2 days |
| **Current state** | Policy exists (`06-incident-response.md`). No executable runbook. |
| **Required state** | Step-by-step runbook; roles assigned; communication templates; tested via tabletop |
| **Evidence** | `policies/06-incident-response.md` exists; no runbook directory |
| **Risk if skipped** | Chaotic incident response; GDPR 72h notification missed; SOC 2 CC7.3 failure |

**Plan:**
1. Write executable incident runbook — 1 day
2. Conduct tabletop exercise — 1 day

---

### B12: OSS registration incomplete

| Field | Value |
|-------|-------|
| **Severity** | Medium-High |
| **Blocks** | Production (B2C cross-border EU sales) |
| **Owner** | Legal/finance |
| **Effort** | 1–2 weeks (depends on VMI processing) |
| **Current state** | `corporate/registrations/oss/` directory exists. No filing evidence. |
| **Required state** | OSS registration completed with VMI; quarterly filing mechanism |
| **Evidence** | Directory exists but no registration confirmation |
| **Risk if skipped** | VAT non-compliance for cross-border B2C; fines per country |

---

## Effort Summary

| Category | Critical | High | Total |
|----------|----------|------|-------|
| Infrastructure (Ansible, WireGuard, Vault, nginx, monitoring) | 5 | 2 | 7 |
| Data (backups, restore drill) | 2 | 0 | 2 |
| Compliance (DPIA, incident runbook) | 1 | 1 | 2 |
| Application (VIES, CodeQL) | 0 | 2 | 2 |
| Legal/finance (OSS) | 0 | 1 | 1 |
| **Total** | **8** | **6** | **14** |

### Estimated timeline

| Phase | Duration | Prerequisites |
|-------|----------|---------------|
| Ansible core roles (hardening, WireGuard, PostgreSQL, Vault) | 2 weeks | Proxmox available |
| Backup implementation + restore drill | 1 week | Ansible roles done |
| nginx edge + monitoring | 3 days | Ansible roles done |
| DPIA-003 signature | 1–2 weeks | DPO available |
| VIES live wiring | 3–5 days | Backend engineer |
| CodeQL/SAST enablement | 2 days | Security engineer |
| Incident runbook + tabletop | 2 days | Security lead + DPO |
| **Total to production-ready** | **4–6 weeks** | All blockers resolved |

### 3-day milestone (realistic)

```
Day 1: Proxmox arrives → install + harden host
Day 2: Create VMs/LXCs → WireGuard mesh → Vault bootstrap
Day 3: Deploy staging (PostgreSQL + Django + nginx) → smoke tests
```

**This gets you a staging environment. NOT production.**
