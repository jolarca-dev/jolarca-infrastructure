---
text: incident-runbook
version: 1.0.0
status: approved
---

# Incident Runbook — Top 5 Failure Modes

**Purpose:** Step-by-step response procedures for the most likely
production failures. Each procedure includes: detection, impact,
immediate action, escalation, and rollback.
**Audience:** On-call operator. No tribal knowledge required.

---

## 1. Database Down

### Detection
- **Alert:** `PostgreSQLDown` (page, fires after 1m)
- **Symptom:** All API endpoints return 502/503; Django backend logs show
  `connection refused` to 10.10.1.3:5432

### Impact
- **Severity:** P1 — complete service outage
- **User impact:** All users cannot access the marketplace
- **Data risk:** No data loss if PG process crashes; potential data loss
  if disk failure

### Immediate Action

```bash
# 1. SSH to DB host
ssh deploy@10.10.1.3

# 2. Check PostgreSQL status
sudo systemctl status postgresql

# 3. Check PostgreSQL logs
sudo journalctl -u postgresql --since "10 minutes ago" | tail -50

# 4. Try to restart
sudo systemctl restart postgresql

# 5. Verify
sudo -u postgres psql -d jol_marketplace -c "SELECT 1;"

# 6. If restart fails, check disk space
df -h /var/lib/postgresql

# 7. If disk full, check WAL accumulation
ls -lh /var/backups/postgresql/wal/ | wc -l
```

### Escalation
- If PG doesn't restart within 5 minutes → page infrastructure lead
- If disk failure suspected → page infrastructure lead + prepare restore from backup

### Rollback
- If data corruption: follow `docs/backup-restore-runbook.md` Procedure 2
- If disk failure: provision new VM, restore from BorgBackup

---

## 2. Payment Webhook Failure

### Detection
- **Alert:** `StripeWebhookFailures` (page, fires after 10m of elevated rate)
- **Symptom:** Stripe dashboard shows failed webhook deliveries; orders
  not updating to "paid" status

### Impact
- **Severity:** P1 — payments processing broken
- **User impact:** Buyers may have been charged but orders not fulfilled
- **Data risk:** Financial inconsistency between Stripe and marketplace

### Immediate Action

```bash
# 1. Check Stripe webhook status
# Log in to Stripe Dashboard → Developers → Webhooks → check delivery status

# 2. Check backend webhook endpoint
ssh deploy@10.10.1.2
curl -sk https://10.10.1.1/api/v1/payments/webhooks/stripe/ -X POST \
  -H "Content-Type: application/json" -d '{}' | head -5

# 3. Check backend logs for webhook errors
sudo journalctl -u jol-backend --since "30 minutes ago" | grep -i webhook | tail -20

# 4. Check if the endpoint is reachable from Stripe
# Stripe needs to reach https://marketplace.jolarca.org/api/v1/payments/webhooks/stripe/
# Verify DNS and nginx routing:
ssh deploy@10.10.1.1
curl -sk https://127.0.0.1/api/v1/payments/webhooks/stripe/ -X POST \
  -H "Content-Type: application/json" -d '{}' | head -5

# 5. Check if the webhook secret is correct
ssh deploy@10.10.1.2
grep STRIPE_WEBHOOK_SECRET /opt/jolarca/config/app.env
```

### Escalation
- If endpoint is unreachable from internet → check nginx, DNS, firewall
- If webhook secret mismatch → update secret in Vault, redeploy
- If orders out of sync → page backend lead for manual reconciliation

### Rollback
- Revert last deployment if webhook handler code changed
- Use Stripe Dashboard to manually retry failed webhook events

---

## 3. Vault Sealed

### Detection
- **Alert:** `VaultSealed` (page, fires after 1m)
- **Symptom:** All services requiring secrets fail; app logs show
  "Vault is sealed" or "permission denied"

### Impact
- **Severity:** P1 — all secrets inaccessible
- **User impact:** Complete service outage (app can't connect to DB,
  MinIO, Stripe)
- **Data risk:** No data loss; Vault data is encrypted on disk

### Immediate Action

```bash
# 1. SSH to Vault host
ssh deploy@10.10.1.4

# 2. Check Vault status
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true
vault status

# 3. Unseal Vault (requires 3 of 5 key shares)
# Each key holder provides their key:
vault operator unseal  # Enter key share 1
vault operator unseal  # Enter key share 2
vault operator unseal  # Enter key share 3

# 4. Verify Vault is unsealed
vault status
# Should show: Sealed = false

# 5. Verify services recover
curl -sk https://10.10.1.1/health
```

### Escalation
- If fewer than 3 key holders available → page all key holders
- If Vault data corrupted → page infrastructure lead; restore raft snapshot from backup

### Rollback
- Restore from raft snapshot: `vault operator raft snapshot restore /var/backups/vault/LATEST.snap`
- If all else fails: reinitialize Vault and re-populate secrets

---

## 4. Backup Stale

### Detection
- **Alert:** `BackupStale` (page, fires after 25h without successful backup)
- **Alert:** `BackupFailed` (page, fires when last exit code != 0)
- **Symptom:** `/var/backups/last-backup-status` shows old timestamp

### Impact
- **Severity:** P1 — data loss risk if disaster occurs without current backup
- **User impact:** No direct user impact
- **Data risk:** RPO violated; potential data loss up to the last good backup

### Immediate Action

```bash
# 1. SSH to backup host
ssh deploy@10.10.1.7

# 2. Check backup status
cat /var/backups/last-backup-status
tail -50 /var/log/borg-backup.log

# 3. Check Borg repo health
borg check /var/backups/borg-repo

# 4. Run backup manually
/usr/local/bin/borg-backup.sh

# 5. If manual backup fails, check disk space
df -h /var/backups

# 6. Check if DB host is reachable
ssh deploy@10.10.1.3 "echo OK"

# 7. Check if pg_dump works
/var/backups/scripts/pg-backup.sh
```

### Escalation
- If Borg repo corrupted → page infrastructure lead; consider offsite restore
- If disk full → expand storage or prune old archives
- If DB host unreachable → check WireGuard mesh (see #5)

### Rollback
- If local repo corrupted: restore from offsite target
  ```bash
  borg list borg@offsite-eu:./jolarca-production
  borg extract borg@offsite-eu:./jolarca-production::<archive>
  ```

---

## 5. WireGuard Mesh Failure

### Detection
- **Alert:** `WireGuardHandshakeStale` (page, fires after 10m)
- **Symptom:** Services on different hosts can't communicate; monitoring
  shows targets as unreachable

### Impact
- **Severity:** P1 — the ONLY bridge between data plane and services
- **User impact:** Complete service outage (app can't reach DB, Vault, MinIO)
- **Data risk:** No data loss; connectivity issue only

### Immediate Action

```bash
# 1. From monitor host, check WireGuard status
ssh deploy@10.10.1.6
sudo wg show

# 2. Check each peer's latest handshake
sudo wg show | grep "latest handshake"

# 3. If a peer is stale, restart WireGuard on that host
ssh deploy@<stale-peer-ip>
sudo systemctl restart wg-quick@wg0

# 4. If WireGuard won't restart, check the Proxmox host
# SSH to Proxmox host (not via WireGuard — use direct IP)
ssh root@<proxmox-host-ip>
pct enter <vm-id>
systemctl restart wg-quick@wg0

# 5. If Proxmox host itself is down
# Check from Proxmox web UI or IPMI/iLO
# Start the VM/LXC from Proxmox UI
```

### Escalation
- If Proxmox host down → page infrastructure lead; check hardware
- If multiple peers stale simultaneously → network issue at hosting provider

### Rollback
- If WireGuard config broken: redeploy from Ansible
  ```bash
  ansible-playbook ansible/playbooks/10-wireguard.yml -i inventories/production/hosts.yml
  ```
- If Proxmox host failure: provision new host, restore VMs from backup

---

## Common Patterns

### After Any Resolution

1. Run the smoke test suite: `./scripts/smoke-test-staging.sh`
2. Verify all Prometheus targets are UP: `curl -s http://10.10.1.6:9090/api/v1/targets | python3 -m json.tool | grep health`
3. Clear the alert in Alertmanager (or wait for auto-resolve)
4. File a post-mortem within 24 hours

### Communication During Incident

```
🚨 INCIDENT: [failure mode]
Severity: P1
Started: [timestamp]
Impact: [what's broken for users]
Action: [what you're doing]
ETA: [estimated resolution time]
```

### Post-Incident Checklist

- [ ] Incident resolved
- [ ] All services verified healthy
- [ ] Alerts cleared
- [ ] Post-mortem filed (within 24h)
- [ ] Runbook updated if procedure was unclear
- [ ] Action items assigned and tracked
