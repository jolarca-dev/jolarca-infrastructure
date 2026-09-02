---
text: staging-deployment-runbook
version: 1.0.0
status: approved
---

# Staging Deployment Runbook

**Purpose:** Step-by-step from "fresh Proxmox VMs" to "staging green."
**Audience:** Any operator with SSH access to the WireGuard mesh.
**Prerequisites:** P0 (Proxmox host), P1 (VMs + cloud-init), P2 (Ansible hardening + WireGuard + Vault).

> **WARNING:** This runbook deploys to STAGING only. No pilot traffic.
> Production cutover is a separate gated step (see DEPLOYMENT_GATE.md).

---

## Pre-flight Checklist

Before starting, verify:

- [ ] All 7 VMs/LXCs are running (VMIDs 100-103, 200-202)
- [ ] WireGuard mesh is up (`wg show` on each node shows peers)
- [ ] Vault is initialized and unsealed
- [ ] SSH key access works from operator machine to all nodes
- [ ] Ansible inventory has correct WireGuard IPs uncommented
- [ ] `ansible-vault` password file exists (`.vault-password` or set `ANSIBLE_VAULT_PASSWORD_FILE`)

```bash
# Verify connectivity to all hosts
cd ansible
ansible all -i inventories/staging/hosts.yml -m ping
```

---

## Phase 1: Infrastructure Hardening (00 → 10)

**Time:** ~10 minutes

### Step 1.1: Apply CIS baseline hardening

```bash
ansible-playbook playbooks/00-hardening.yml \
  -i inventories/staging/hosts.yml \
  --diff
```

**Verify:** SSH is key-only, nftables default-deny, fail2ban active, auditd running.

### Step 1.2: Configure WireGuard mesh

```bash
ansible-playbook playbooks/10-wireguard.yml \
  -i inventories/staging/hosts.yml \
  --diff
```

**Verify:**
```bash
# On each node
ssh deploy@10.10.1.1 "wg show"  # edge
ssh deploy@10.10.1.2 "wg show"  # app
ssh deploy@10.10.1.3 "wg show"  # db
ssh deploy@10.10.1.4 "wg show"  # vault
```

All nodes should see peers with correct AllowedIPs and latest handshake timestamps.

---

## Phase 2: Data Tier (20 → 30 → 40 → 50)

**Time:** ~20 minutes

### Step 2.1: Deploy PostgreSQL

```bash
ansible-playbook playbooks/40-postgresql.yml \
  -i inventories/staging/hosts.yml \
  --diff
```

**Verify:**
```bash
ssh deploy@10.10.1.3 "sudo -u postgres psql -d jol_marketplace -c '\dx'"
# Should show: postgis, vector, pgcrypto
```

### Step 2.2: Deploy Vault

```bash
ansible-playbook playbooks/30-vault.yml \
  -i inventories/staging/hosts.yml \
  --diff
```

**Verify:**
```bash
curl -sk https://10.10.1.4:8200/v1/sys/health | python3 -m json.tool
# "initialized": true, "sealed": false
```

**Post-deploy: Initialize Vault (first time only)**
```bash
# On vault-staging
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true

# Initialize with 5 key shares, threshold 3
vault operator init -key-shares=5 -key-threshold=3
# SAVE THE OUTPUT — unseal keys + root token

# Unseal (repeat 3 times with different keys)
vault operator unseal <key-share-1>
vault operator unseal <key-share-2>
vault operator unseal <key-share-3>

# Enable KV v2 secrets engine
vault secrets enable -path=secret kv-v2

# Store staging secrets
vault kv put secret/staging/django \
  SECRET_KEY=$(openssl rand -hex 32) \
  DATABASE_URL="postgres://jol_app:PASSWORD@10.10.1.3:5432/jol_marketplace?sslmode=verify-full" \
  STRIPE_SECRET_KEY="sk_test_PLACEHOLDER" \
  STRIPE_WEBHOOK_SECRET="whsec_PLACEHOLDER"

vault kv put secret/staging/postgres \
  password="CHANGE_ME_STRONG_PASSWORD" \
  replication_password="CHANGE_ME_REPLICATION_PASSWORD"

vault kv put secret/staging/minio \
  root-user="minioadmin" \
  root-password="CHANGE_ME_MINIO_PASSWORD"
```

### Step 2.3: Deploy MinIO

```bash
ansible-playbook playbooks/50-minio.yml \
  -i inventories/staging/hosts.yml \
  --diff
```

**Verify:**
```bash
curl -s http://10.10.1.5:9000/minio/health/live
# Should return 200 OK

# Check buckets
ssh deploy@10.10.1.5 "mc ls local"
# Should show: jol-marketplace-media, jol-marketplace-uploads, jol-marketplace-static
```

### Step 2.4: Deploy nginx edge

```bash
ansible-playbook playbooks/70-nginx-edge.yml \
  -i inventories/staging/hosts.yml \
  --diff
```

**Verify:**
```bash
curl -sk https://10.10.1.1/health
# {"status":"ok","service":"edge"}
```

---

## Phase 3: Application Deployment (65)

**Time:** ~15 minutes

### Step 3.1: Deploy Django + Next.js

```bash
ansible-playbook playbooks/65-app.yml \
  -i inventories/staging/hosts.yml \
  --diff \
  -e vault_pg_app_password="$(vault kv get -field=password secret/staging/postgres)" \
  -e vault_django_secret_key="$(vault kv get -field=SECRET_KEY secret/staging/django)"
```

**Verify:**
```bash
# Backend health
curl -s http://10.10.1.2:8000/api/v1/health/
# {"status":"ok", ...}

# Frontend
curl -s -o /dev/null -w '%{http_code}' http://10.10.1.2:3000/
# 200
```

### Step 3.2: Load seed data

```bash
./scripts/seed-staging-data.sh 10.10.1.2
```

**Verify:**
```bash
# Admin login works
curl -s -o /dev/null -w '%{http_code}' http://10.10.1.2:8000/admin/login/
# 200
```

---

## Phase 4: Smoke Tests

**Time:** ~5 minutes

### Step 4.1: Run automated smoke tests

```bash
./scripts/smoke-test-staging.sh 10.10.1.1
```

Expected output:
```
═══════════════════════════════════════════════════════
  Results: 18 passed, 0 failed, 18 total
═══════════════════════════════════════════════════════
  ✅ ALL CHECKS PASSED — staging stack is operational.
```

### Step 4.2: Manual verification

1. **Edge → API:** `curl -sk https://10.10.1.1/api/v1/health/`
2. **Edge → Frontend:** Open `https://10.10.1.1/` in browser (accept self-signed cert)
3. **Admin login:** `https://10.10.1.1/admin/` → login with `admin_staging` / `staging_admin_password_CHANGE_ME`
4. **Catalog renders:** Browse the storefront — synthetic products should appear

---

## Phase 5: Backup Configuration (60)

```bash
ansible-playbook playbooks/60-backup.yml \
  -i inventories/staging/hosts.yml \
  --diff
```

**Verify:**
```bash
ssh deploy@10.10.1.7 "borg --version"
ssh deploy@10.10.1.7 "cat /usr/local/bin/borg-backup.sh | head -5"
```

---

## Troubleshooting

### Vault is sealed

```bash
# On vault-staging
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true
vault operator unseal <key-share-N>  # Repeat 3 times with different keys
```

### Django migrations fail

```bash
# On app-staging
docker compose -f /opt/jolarca/docker-compose.backend.yml exec backend python manage.py migrate --noinput
docker compose -f /opt/jolarca/docker-compose.backend.yml logs backend --tail=50
```

### nginx 502 Bad Gateway

Backend or frontend container is down:
```bash
# On app-staging
docker compose -f /opt/jolarca/docker-compose.backend.yml ps
docker compose -f /opt/jolarca/docker-compose.frontend.yml ps
systemctl restart jol-backend
systemctl restart jol-frontend
```

### WireGuard peers not connecting

```bash
# On each node
wg show  # Check latest handshake
systemctl restart wg-quick@wg0
```

---

## Rollback

If staging deployment fails catastrophically:

1. Stop all application services:
   ```bash
   ssh deploy@10.10.1.2 "systemctl stop jol-backend jol-frontend"
   ```

2. Re-run infrastructure playbooks to restore clean state:
   ```bash
   ansible-playbook playbooks/00-hardening.yml -i inventories/staging/hosts.yml
   ansible-playbook playbooks/10-wireguard.yml -i inventories/staging/hosts.yml
   ```

3. If database is corrupted, restore from backup (see `backup/restore-drill.md`).

---

## Completion Criteria

Staging is "green" when:

- [ ] All 18 smoke tests pass
- [ ] API health endpoint returns 200 via nginx
- [ ] Frontend renders in browser via nginx
- [ ] Admin login works with test credentials
- [ ] Vault is unsealed and secrets are populated
- [ ] MinIO buckets exist and are private
- [ ] PostgreSQL has all extensions enabled
- [ ] WireGuard mesh has all peers connected
- [ ] Backup cron is configured
- [ ] No plaintext secrets in any config file
