---
text: rollback-plan
version: 1.0.0
status: approved
---

# Rollback Plan

**Purpose:** Step-by-step procedures to roll back any deployment component
to the previous known-good state.
**Audience:** Any operator with SSH access and Ansible credentials.
**Principle:** Every deployment is reversible. If it isn't, it isn't deployed.

---

## Rollback Strategy Overview

| Component | Rollback Method | RTO | Data Loss Risk |
|-----------|----------------|-----|----------------|
| Database | `pg_restore` from pre-deploy dump | ≤ 30min | Low (point-in-time) |
| App (Django) | Previous Docker image / git revert | ≤ 15min | None |
| Frontend (Next.js) | Previous Docker image / git revert | ≤ 10min | None |
| nginx config | `git revert` + reload | ≤ 5min | None |
| Terraform state | GCS versioning restore | ≤ 30min | None |
| Vault config | Raft snapshot restore | ≤ 15min | Low |
| Full environment | Ansible + BorgBackup restore | ≤ 4h | Low |

---

## Procedure 1: Database Rollback

### When to use
- Migration broke the schema
- Data corruption from bad deploy
- New feature caused data integrity issues

### Steps

```bash
# ── Step 1: Stop the application ────────────────────────────────────
ssh deploy@10.10.1.2
sudo systemctl stop jol-backend
sudo systemctl stop jol-celery-worker
sudo systemctl stop jol-celery-beat

# ── Step 2: Find the pre-deploy backup ──────────────────────────────
ssh deploy@10.10.1.7
ls -lt /var/backups/postgresql/*.dump | head -5

# ── Step 3: Drop and restore ────────────────────────────────────────
ssh deploy@10.10.1.3
sudo -u postgres psql -c "DROP DATABASE IF EXISTS jol_marketplace;"
sudo -u postgres psql -c "CREATE DATABASE jol_marketplace ENCODING 'UTF8';"
sudo -u postgres pg_restore -d jol_marketplace /tmp/jol_marketplace_PRE_DEPLOY.dump

# ── Step 4: Re-enable extensions ────────────────────────────────────
sudo -u postgres psql -d jol_marketplace -c "
  CREATE EXTENSION IF NOT EXISTS postgis;
  CREATE EXTENSION IF NOT EXISTS vector;
  CREATE EXTENSION IF NOT EXISTS pgcrypto;
"

# ── Step 5: Restart application ─────────────────────────────────────
ssh deploy@10.10.1.2
sudo systemctl start jol-backend
sudo systemctl start jol-celery-worker
sudo systemctl start jol-celery-beat

# ── Step 6: Verify ──────────────────────────────────────────────────
curl -s https://10.10.1.1/api/v1/health/ | python3 -m json.tool
```

### Pre-deploy backup hook
Add this to your deployment script to automatically create a pre-deploy backup:

```bash
# In deploy.sh, before running migrations:
ssh deploy@10.10.1.7 "/var/backups/scripts/pg-backup.sh"
```

---

## Procedure 2: Application Rollback (Django)

### When to use
- New code has bugs
- Dependency update broke functionality
- Configuration change caused errors

### Steps

```bash
# ── Step 1: Identify the previous good version ──────────────────────
ssh deploy@10.10.1.2
cd /opt/jolarca/backend
git log --oneline -10
# Find the last known-good commit

# ── Step 2: Revert to previous version ──────────────────────────────
git checkout <previous-good-commit>

# ── Step 3: Rebuild and restart ─────────────────────────────────────
docker compose -f /opt/jolarca/docker-compose.backend.yml down
docker compose -f /opt/jolarca/docker-compose.backend.yml up -d --build

# ── Step 4: Verify ──────────────────────────────────────────────────
curl -s https://10.10.1.1/api/v1/health/ | python3 -m json.tool
```

### Alternative: Roll back Docker image
If using tagged images:

```bash
# Find the previous image tag
docker images | grep jol-backend

# Restart with previous image
docker compose -f /opt/jolarca/docker-compose.backend.yml down
docker compose -f /opt/jolarca/docker-compose.backend.yml up -d
```

---

## Procedure 3: Frontend Rollback (Next.js)

### When to use
- UI regression
- Build broke in production
- Asset loading issues

### Steps

```bash
# ── Step 1: Revert to previous version ──────────────────────────────
ssh deploy@10.10.1.2
cd /opt/jolarca/frontend
git checkout <previous-good-commit>

# ── Step 2: Rebuild and restart ─────────────────────────────────────
docker compose -f /opt/jolarca/docker-compose.frontend.yml down
docker compose -f /opt/jolarca/docker-compose.frontend.yml up -d --build

# ── Step 3: Verify ──────────────────────────────────────────────────
curl -s https://10.10.1.1/ | head -20
```

---

## Procedure 4: nginx Configuration Rollback

### When to use
- WAF rules blocking legitimate traffic
- TLS config broke connectivity
- Upstream routing misconfigured

### Steps

```bash
# ── Step 1: Find the previous config ────────────────────────────────
ssh deploy@10.10.1.1
cd /opt/jolarca-infrastructure
git log --oneline -5 -- ansible/roles/nginx/templates/

# ── Step 2: Revert the config ───────────────────────────────────────
git checkout <previous-commit> -- ansible/roles/nginx/templates/marketplace.conf.j2

# ── Step 3: Redeploy ────────────────────────────────────────────────
ansible-playbook ansible/playbooks/70-nginx-edge.yml \
  -i ansible/inventories/staging/hosts.yml \
  --tags "nginx,marketplace"

# ── Step 4: Verify ──────────────────────────────────────────────────
curl -sk https://10.10.1.1/health | python3 -m json.tool
```

### Emergency: Direct nginx rollback (without Ansible)

```bash
# If Ansible is unavailable, edit directly:
ssh deploy@10.10.1.1
sudo vi /etc/nginx/sites-available/marketplace
# Make changes, then:
sudo nginx -t && sudo systemctl reload nginx
```

---

## Procedure 5: Terraform State Rollback

### When to use
- `terraform apply` corrupted state
- Resources deleted accidentally
- State drift detected

### Steps

```bash
# ── Step 1: List state versions ─────────────────────────────────────
gcloud storage objects list \
  gs://jolm-tfstate-staging-3c4a45/terraform/staging/ \
  --versions | head -10

# ── Step 2: Download previous state ─────────────────────────────────
gcloud storage cp \
  gs://jolm-tfstate-staging-3c4a45/terraform/staging/default.tfstate#GENERATION \
  /tmp/previous-state.tfstate

# ── Step 3: Restore state ───────────────────────────────────────────
terraform state push /tmp/previous-state.tfstate

# ── Step 4: Verify ──────────────────────────────────────────────────
terraform plan
# Should show no changes (or only expected drift)
```

---

## Procedure 6: Full Environment Rollback

### When to use
- Multiple components broken
- Catastrophic deployment failure
- Need to restore to known-good baseline

### Steps

```bash
# ── Step 1: Run the restore drill ───────────────────────────────────
./scripts/restore-drill.sh /var/backups/borg-repo /tmp/restore-drill

# ── Step 2: If drill passes, restore from backup ────────────────────
# Follow docs/backup-restore-runbook.md Procedure 3

# ── Step 3: Verify full stack ───────────────────────────────────────
./scripts/smoke-test-staging.sh
```

---

## Rollback Decision Tree

```
Deployment went wrong?
├── Single component broken?
│   ├── Database → Procedure 1 (pg_restore)
│   ├── Backend → Procedure 2 (git checkout + rebuild)
│   ├── Frontend → Procedure 3 (git checkout + rebuild)
│   └── nginx → Procedure 4 (git revert + redeploy)
├── Multiple components broken?
│   └── Procedure 6 (full environment restore)
└── State corruption?
    └── Procedure 5 (Terraform state rollback)
```

---

## Pre-Deployment Checklist

Before every deployment, verify:

- [ ] Pre-deploy backup exists: `ls -lt /var/backups/postgresql/*.dump | head -1`
- [ ] BorgBackup is current: `cat /var/backups/last-backup-status`
- [ ] Git working tree is clean: `git status`
- [ ] Smoke tests pass on current version: `./scripts/smoke-test-staging.sh`
- [ ] Rollback plan reviewed: this document
- [ ] On-call operator identified: see incident response runbook
