---
text: backup-restore-runbook
version: 1.0.0
status: approved
---

# Backup & Restore Runbook

**Purpose:** Step-by-step procedures for backup verification and full
environment restore from backup.
**Audience:** Any operator with SSH access to the backup host.
**Targets:** RTO ≤ 4h, RPO ≤ 15min.

---

## Backup Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                     BACKUP HOST (CT-202)                      │
│                                                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │ pg_dump     │  │ mc mirror   │  │ vault snap  │          │
│  │ (every 4h)  │  │ (daily)     │  │ (every 6h)  │          │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │
│         │                │                │                   │
│         ▼                ▼                ▼                   │
│  /var/backups/    /var/backups/    /var/backups/             │
│  postgresql/      minio/           vault/                    │
│         │                │                │                   │
│         └────────────────┼────────────────┘                   │
│                          │                                    │
│                          ▼                                    │
│              ┌─────────────────────┐                          │
│              │   BorgBackup        │                          │
│              │   (repokey-blake2)  │                          │
│              │   daily 02:00       │                          │
│              └─────────┬───────────┘                          │
│                        │                                      │
│                        ▼                                      │
│              /var/backups/borg-repo                           │
│              (encrypted, deduplicated)                        │
│                        │                                      │
│                        ▼ (offsite sync, 04:00)                │
│              ┌─────────────────────┐                          │
│              │   Offsite Target    │                          │
│              │   (EU, encrypted)   │                          │
│              └─────────────────────┘                          │
└──────────────────────────────────────────────────────────────┘
```

## What Gets Backed Up

| Component | Method | Schedule | Retention |
|-----------|--------|----------|-----------|
| PostgreSQL (pg_dump) | `pg_dump -Fc` per database | Every 4 hours | 7 days |
| PostgreSQL WAL | `archive_command` → local dir | Continuous | 7 days |
| MinIO buckets | `mc mirror` per bucket | Daily | 30 days |
| Vault raft snapshot | `vault operator raft snapshot save` | Every 6 hours | 7 days |
| App config | BorgBackup (config dir, compose files) | Daily | 7/4/12 |
| System config (/etc) | BorgBackup | Daily | 7/4/12 |

## Retention Policy

| Period | Count | Description |
|--------|-------|-------------|
| Daily | 7 | Last 7 daily backups |
| Weekly | 4 | Last 4 weekly backups |
| Monthly | 12 | Last 12 monthly backups |

Enforced by `borg prune` (weekly on Sunday at 03:00).

---

## Procedure 1: Verify Backups Are Running

```bash
# SSH to backup host
ssh deploy@10.10.1.7

# Check last backup status
cat /var/backups/last-backup-status

# Check backup log (last 20 lines)
tail -20 /var/log/borg-backup.log

# List Borg archives
borg list /var/backups/borg-repo

# Run the staleness monitor manually
/usr/local/bin/backup-monitor.sh

# Verify cron jobs
crontab -l | grep -i borg
```

---

## Procedure 2: Restore PostgreSQL from Backup

```bash
# SSH to backup host
ssh deploy@10.10.1.7

# Find the latest dump
ls -lt /var/backups/postgresql/*.dump | head -5

# Copy dump to DB host
scp /var/backups/postgresql/jol_marketplace_*.dump deploy@10.10.1.3:/tmp/

# SSH to DB host
ssh deploy@10.10.1.3

# Drop and recreate the database
sudo -u postgres psql -c "DROP DATABASE IF EXISTS jol_marketplace;"
sudo -u postgres psql -c "CREATE DATABASE jol_marketplace ENCODING 'UTF8';"

# Restore the dump
sudo -u postgres pg_restore -d jol_marketplace /tmp/jol_marketplace_LATEST.dump

# Re-enable extensions
sudo -u postgres psql -d jol_marketplace -c "
  CREATE EXTENSION IF NOT EXISTS postgis;
  CREATE EXTENSION IF NOT EXISTS vector;
  CREATE EXTENSION IF NOT EXISTS pgcrypto;
"

# Verify
sudo -u postgres psql -d jol_marketplace -c "SELECT count(*) FROM pg_tables WHERE schemaname = 'public';"
```

---

## Procedure 3: Full Environment Restore from BorgBackup

### Prerequisites
- Fresh VM with Debian 12 installed
- SSH access from backup host
- BorgBackup installed on the fresh VM

### Steps

```bash
# ── Step 1: Install BorgBackup on target ─────────────────────────
ssh deploy@<target-host>
sudo apt-get update && sudo apt-get install -y borgbackup

# ── Step 2: Mount/access the Borg repository ─────────────────────
# Option A: Copy repo from backup host
scp -r deploy@10.10.1.7:/var/backups/borg-repo /tmp/borg-repo

# Option B: Mount via SSHFS
sshfs deploy@10.10.1.7:/var/backups/borg-repo /mnt/borg-repo

# ── Step 3: List available archives ──────────────────────────────
borg list /tmp/borg-repo
# or: borg list /mnt/borg-repo

# ── Step 4: Extract the latest archive ───────────────────────────
mkdir -p /tmp/restore
cd /tmp/restore
borg extract /tmp/borg-repo::<archive-name>

# ── Step 5: Restore PostgreSQL ───────────────────────────────────
# Copy the dump to the DB host and restore (see Procedure 2)

# ── Step 6: Restore MinIO ────────────────────────────────────────
# Copy bucket data back to MinIO host
scp -r /tmp/restore/var/backups/minio/* deploy@10.10.1.5:/data/minio/

# ── Step 7: Restore Vault ────────────────────────────────────────
# Copy raft snapshot to Vault host
scp /tmp/restore/var/backups/vault/vault-raft_*.snap deploy@10.10.1.4:/tmp/

# On Vault host:
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true
vault operator raft snapshot restore /tmp/vault-raft_LATEST.snap

# ── Step 8: Restore app config ───────────────────────────────────
scp -r /tmp/restore/opt/jolarca/config deploy@10.10.1.2:/opt/jolarca/
scp /tmp/restore/opt/jolarca/docker-compose.*.yml deploy@10.10.1.2:/opt/jolarca/

# ── Step 9: Run Ansible to re-harden and reconfigure ─────────────
cd /path/to/jolarca-infrastructure/ansible
ansible-playbook playbooks/00-hardening.yml -i inventories/staging/hosts.yml
ansible-playbook playbooks/10-wireguard.yml -i inventories/staging/hosts.yml
ansible-playbook playbooks/65-app.yml -i inventories/staging/hosts.yml

# ── Step 10: Run smoke tests ─────────────────────────────────────
./scripts/smoke-test-staging.sh
```

---

## Procedure 4: Automated Restore Drill

```bash
# Run the automated drill from the backup host
ssh deploy@10.10.1.7
./scripts/restore-drill.sh /var/backups/borg-repo /tmp/restore-drill

# Or from any host with access to the Borg repo:
./scripts/restore-drill.sh /path/to/borg-repo /tmp/restore-drill
```

The drill script:
1. Finds the latest Borg archive
2. Extracts it to a temporary directory
3. Verifies PostgreSQL dumps are valid (`pg_restore --list`)
4. Verifies MinIO buckets are present
5. Verifies Vault snapshots exist
6. Verifies app config files are present
7. Reports pass/fail with timing

---

## Monitoring & Alerting

### Backup staleness alert
- **Check:** `/usr/local/bin/backup-monitor.sh` runs every hour
- **Alert threshold:** No successful backup in 25 hours
- **Log:** `/var/log/borg-backup.log`
- **Status file:** `/var/backups/last-backup-status`

### Manual monitoring
```bash
# Check backup health
/usr/local/bin/backup-monitor.sh

# View recent backup activity
tail -50 /var/log/borg-backup.log

# Check Borg repo size
borg info /var/backups/borg-repo
```

---

## Offsite Strategy

| Parameter | Value |
|-----------|-------|
| Provider | EU-based (Hetzner Storage Box or equivalent) |
| Region | EU (GDPR Art. 44 compliant) |
| Encryption | Borg repokey-blake2 (provider never sees plaintext) |
| Sync method | `borg sync` (incremental) |
| Schedule | Daily at 04:00 |
| Append-only | Where provider supports it |
| Independent restore | Yes — offsite restore works without primary DC |

### Offsite restore (cold recovery)
```bash
# From any machine with SSH access to offsite target
borg list borg@offsite-eu:./jolarca-staging
borg extract borg@offsite-eu:./jolarca-staging::<archive-name>
```

---

## Emergency Contacts

| Role | Contact | When to call |
|------|---------|-------------|
| Infrastructure lead | [name] | Backup failure, restore needed |
| DPO | dpo@journeyoflife.org | Data breach involving backup data |
| Offsite provider support | [provider contact] | Offsite repo inaccessible |
