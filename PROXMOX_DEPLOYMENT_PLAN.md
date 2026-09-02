# PROXMOX DEPLOYMENT PLAN — jolarca-marketplace

**Date:** 2026-09-02  
**Target:** Proxmox VE bare-metal host (arriving ~Day 0)  
**Scope:** Staging environment first; production cutover is a separate gated step  
**Compliance:** CIS baseline hardening, WireGuard mesh, Vault secrets, BorgBackup

> **Status:** This plan is a SPECIFICATION. The Ansible playbooks to execute it
> do not yet exist. They must be written before deployment can proceed.

---

## 1. Proxmox Host Hardening (CIS Baseline)

### 1.1 Host-level hardening

```yaml
# Proxmox VE hardening checklist (CIS Debian Benchmark + PVE-specific)

# Disk encryption
- LUKS full-disk encryption on install (all partitions except /boot)
- Swap encrypted (or use zram without swap-to-disk)

# SSH
- Disable root login (PermitRootLogin no)
- Key-only authentication (PasswordAuthentication no)
- Fail2ban enabled (max 3 attempts, 15min ban)

# Firewall (proxmox-firewall or iptables)
- Default DENY inbound
- Allow: 22 (SSH), 8006 (PVE GUI — restricted to admin IPs), 60000-60050/udp (Live migration)
- Block all other inbound

# Services
- Disable unused services (Samba, FTP, telnet)
- AppArmor enabled and enforcing

# Audit
- auditd enabled (log all execve, file access to /etc/shadow, /etc/passwd)
- Log forwarding to remote syslog (off-host)

# Updates
- unattended-upgrades for security patches
- Proxmox no-subscription repo (or subscription if licensed)
```

### 1.2 Network segmentation

```
┌─────────────────────────────────────────────────────────────────┐
│                     PROXMOX HOST                                  │
│                                                                   │
│  ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐         │
│  │ VM-100  │   │ VM-101  │   │ VM-102  │   │ VM-103  │         │
│  │ edge    │   │ app     │   │ db      │   │ vault   │         │
│  │ nginx   │   │ django  │   │ pg+post │   │ hashi   │         │
│  │ TLS     │◄──┤ next.js │──►│ gis     │   │ unseal  │         │
│  │ rate    │   │ celery  │   │         │   │ keys    │         │
│  └────┬────┘   └────┬────┘   └────┬────┘   └────┬────┘         │
│       │              │              │              │               │
│       └──────────────┴──────────────┴──────────────┘              │
│                      WireGuard mesh (wg0)                         │
│                      10.10.0.0/16                                 │
│                                                                   │
│  ┌─────────┐   ┌─────────┐   ┌─────────┐                        │
│  │ CT-200  │   │ CT-201  │   │ CT-202  │                        │
│  │ minio   │   │ prom    │   │ borg    │                        │
│  │ object  │   │ grafana │   │ backup  │                        │
│  │ storage │   │ alert   │   │ agent   │                        │
│  └─────────┘   └─────────┘   └─────────┘                        │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
         │
         │ TLS 1.3 (Let's Encrypt staging)
         ▼
    INTERNET (port 443 only → VM-100 nginx)
```

### 1.3 VM/LXC layout

| ID | Type | Hostname | Role | CPU | RAM | Disk | Network |
|----|------|----------|------|-----|-----|------|---------|
| 100 | VM | edge-staging | nginx reverse proxy, TLS termination | 2 | 2G | 20G | wg0 + public:443 |
| 101 | VM | app-staging | Django + Next.js + Celery | 4 | 8G | 40G | wg0 only |
| 102 | VM | db-staging | PostgreSQL 17 + PostGIS 3.5 | 4 | 8G | 100G | wg0 only |
| 103 | VM | vault-staging | HashiCorp Vault | 1 | 1G | 10G | wg0 only |
| 200 | LXC | minio-staging | Object storage (media, backups staging) | 2 | 4G | 200G | wg0 only |
| 201 | LXC | monitor-staging | Prometheus + Grafana + Alertmanager | 2 | 4G | 40G | wg0 only |
| 202 | LXC | backup-staging | BorgBackup client + offsite sync | 1 | 2G | 500G | wg0 + offsite |

---

## 2. WireGuard Mesh

### 2.1 Topology

```
[edge-staging] ←──wg0──→ [app-staging]
      │                        │
      │                        │
   [db-staging] ←──wg0──→ [vault-staging]
```

### 2.2 Configuration

```ini
# /etc/wireguard/wg0.conf (app-staging example)

[Interface]
PrivateKey = <app-staging-private-key>
Address = 10.10.1.2/24
ListenPort = 51820

[Peer]
# edge-staging
PublicKey = <edge-public-key>
AllowedIPs = 10.10.1.1/32
Endpoint = 10.10.1.1:51820

[Peer]
# db-staging
PublicKey = <db-public-key>
AllowedIPs = 10.10.1.3/32

[Peer]
# vault-staging
PublicKey = <vault-public-key>
AllowedIPs = 10.10.1.4/32
```

### 2.3 Key custody

- Keys generated on each VM during provisioning (`wg genkey`)
- Public keys exchanged via Vault KV (`secret/network/wireguard/`)
- Private keys NEVER leave the VM they were generated on
- Rotation: `docs/runbooks/wireguard-key-rotation.md` (quarterly)

---

## 3. Secrets: Vault Bootstrap

### 3.1 Vault initialization

```bash
# On vault-staging (VM-103)

# Initialize with 5 key shares, 3 threshold
vault operator init -key-shares=5 -key-threshold=3

# Store unseal keys via split custody (Shamir)
# Key holder 1: operations lead
# Key holder 2: security lead  
# Key holder 3: CTO
# (5 keys, any 3 to unseal)

# Unseal
vault operator unseal <key-share-1>
vault operator unseal <key-share-2>
vault operator unseal <key-share-3>

# Enable KV v2
vault secrets enable -path=secret kv-v2

# Enable PKI
vault secrets enable -path=pki pki
vault secrets tune -max-lease-ttl=87600h pki
```

### 3.2 Secret paths

```
secret/
├── staging/
│   ├── django/
│   │   ├── SECRET_KEY
│   │   ├── DATABASE_URL
│   │   ├── STRIPE_SECRET_KEY (test mode)
│   │   └── STRIPE_WEBHOOK_SECRET
│   ├── postgres/
│   │   ├── password
│   │   └── replication_password
│   ├── minio/
│   │   ├── root-user
│   │   └── root-password
│   └── wireguard/
│       ├── edge/private-key
│       ├── app/private-key
│       ├── db/private-key
│       └── vault/private-key
└── pki/
    ├── root (internal CA)
    └── intermediate (service certs)
```

### 3.3 Ansible Vault vs HashiCorp Vault

| Use case | Tool | Rationale |
|----------|------|-----------|
| Ansible playbook secrets (SSH keys, DB passwords during provisioning) | ansible-vault | Encrypted at rest in repo; dual-control password |
| Runtime application secrets (Django, Stripe, etc.) | HashiCorp Vault | Dynamic secrets, audit log, auto-rotation |
| CI/CD secrets (GitHub tokens) | GitHub Secrets | Scoped to repo; never in code |

---

## 4. Backups: BorgBackup

### 4.1 Backup plan

| Target | Schedule | Retention | Offsite |
|--------|----------|-----------|---------|
| PostgreSQL (PITR) | Continuous (WAL archiving) | 7 days | Yes (encrypted) |
| MinIO objects | Daily | 30 days | Yes (encrypted) |
| Application config | Daily | 90 days | Yes (encrypted) |
| Terraform state | Every plan/apply | Indefinite (versioned bucket) | Yes (GCP) |

### 4.2 Borg configuration

```bash
# On backup-staging (CT-202)

# Initialize repo (repokey-blake2 encryption)
borg init --encryption=repokey-blake2 borg@offsite-eu:./jolarca-staging

# Daily backup script
borg create \
  --compression zstd,6 \
  --one-file-system \
  borg@offsite-eu:./jolarca-staging::{now:%Y-%m-%d} \
  /var/lib/postgresql/17/main/backup/ \
  /var/lib/minio/ \
  /etc/jolarca/

# Retention policy
borg prune --keep-daily=7 --keep-weekly=4 --keep-monthly=12 borg@offsite-eu:./jolarca-staging
```

### 4.3 Offsite target

- Provider: EU-based (Hetzner Storage Box or equivalent)
- Region: EU (GDPR Art. 44 — no transfer outside EEA)
- Encryption: Borg repokey (provider never sees plaintext)
- Append-only: Where provider supports it

### 4.4 Restore drill (quarterly)

```bash
# Drill procedure (per restore-drill.md)

# 1. State restore
#    Recover Terraform state from versioned bucket → scratch bucket
#    Run plan against live → verify no drift

# 2. Data restore
#    Restore PostgreSQL PITR snapshot to test DB
#    Verify RPO ≤ 15min

# 3. Offsite restore
#    Pull one Borg archive from offsite
#    Extract canary file → verify checksum

# 4. Rebuild path
#    Rebuild one node from zero using ansible/playbooks/90-disaster-recovery.yml
```

---

## 5. Staging-First Deployment

### 5.1 Deployment sequence

```
Phase 1: Host bootstrap (Day 1)
  1. Install Proxmox VE
  2. Harden host (CIS baseline)
  3. Configure storage (ZFS or LVM-thin)
  4. Configure network (bridge, VLANs)

Phase 2: VM/LXC creation (Day 2)
  1. Create VMs per layout table
  2. Install Debian 12 in each VM
  3. Configure WireGuard mesh
  4. Bootstrap Vault (VM-103)

Phase 3: Service deployment (Day 3)
  1. PostgreSQL + PostGIS (VM-102)
  2. MinIO (CT-200)
  3. Django application (VM-101) — TEST mode
  4. nginx edge (VM-100) — staging TLS
  5. Prometheus + Grafana (CT-201)
  6. BorgBackup agent (CT-202)

Phase 4: Smoke tests (Day 3)
  1. Health check: /api/v1/health/
  2. Database connectivity
  3. Stripe test-mode webhook
  4. PII encryption round-trip
  5. Backup test (create + restore)
```

### 5.2 Production cutover criteria

Production cutover is a **separate gated step** after:

1. ✅ All Critical gate items pass (see DEPLOYMENT_GATE.md)
2. ✅ DPIA-003 signed by DPO
3. ✅ VIES wired to live EU gateway
4. ✅ Backup + restore drill completed (timestamped evidence)
5. ✅ Monitoring armed + alerting tested (PagerDuty/email)
6. ✅ Incident runbook tested (tabletop exercise)
7. ✅ Rollback procedure tested per service

---

## 6. Rollback

### 6.1 Per-service rollback

| Service | Rollback method | RTO |
|---------|----------------|-----|
| Django app | Deploy previous Docker image tag | 5 min |
| PostgreSQL | Restore from PITR backup | 30 min |
| nginx | Revert config + reload | 1 min |
| Vault | Restore from snapshot | 15 min |
| MinIO | Restore from Borg archive | 30 min |

### 6.2 Full-environment rollback

```bash
# Nuclear option: rebuild from zero
# 1. Wipe all VMs/LXCs
# 2. Re-run Ansible playbooks from scratch
# 3. Restore PostgreSQL from latest PITR
# 4. Restore MinIO from latest Borg archive
# 5. Restore Vault from snapshot
# 6. Re-establish WireGuard mesh
# 7. Smoke tests

# Target: RTO ≤ 4 hours
```

### 6.3 Rollback testing

- **Frequency:** Quarterly (aligned with restore drill)
- **Method:** Full rebuild in isolated test environment
- **Evidence:** Timestamped log with pass/fail per step
