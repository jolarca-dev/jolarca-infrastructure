---
text: incident-response-deployment
version: 1.0.0
status: approved
---

# Incident Response: Deployment Failure

**Purpose:** Immediate actions when a deployment goes wrong.
**Audience:** On-call operator, infrastructure lead, engineering team.
**Severity:** P1 (service down) or P2 (degraded service).

---

## Immediate Actions (First 5 Minutes)

### Step 1: Assess the situation

```bash
# Check what's broken
curl -sk https://10.10.1.1/health
curl -sk https://10.10.1.1/api/v1/health/

# Check nginx status
ssh deploy@10.10.1.1 "sudo systemctl status nginx"

# Check backend status
ssh deploy@10.10.1.2 "sudo systemctl status jol-backend"

# Check database connectivity
ssh deploy@10.10.1.3 "sudo -u postgres psql -d jol_marketplace -c 'SELECT 1;'"
```

### Step 2: Determine severity

| Symptom | Severity | Action |
|---------|----------|--------|
| All endpoints down | **P1** | Immediate rollback (Procedure 6) |
| API broken, frontend up | **P1** | Backend rollback (Procedure 2) |
| Frontend broken, API up | **P2** | Frontend rollback (Procedure 3) |
| Slow response, not down | **P2** | Check logs, then rollback if needed |
| WAF blocking legit traffic | **P2** | nginx rollback (Procedure 4) |
| Database errors | **P1** | Database rollback (Procedure 1) |

### Step 3: Page the right people

```bash
# On-call rotation (update with actual contacts)
# Infrastructure lead: [name] — [phone/email]
# Backend lead: [name] — [phone/email]
# DPO (if data breach): dpo@journeyoflife.org
```

---

## Rollback Decision Matrix

### Scenario A: Just deployed, something broke immediately

**Action:** Roll back the component that was just deployed.

```bash
# If you deployed backend:
ssh deploy@10.10.1.2
cd /opt/jolarca/backend
git checkout HEAD~1  # Previous commit
docker compose -f /opt/jolarca/docker-compose.backend.yml down
docker compose -f /opt/jolarca/docker-compose.backend.yml up -d --build

# Verify
curl -sk https://10.10.1.1/api/v1/health/
```

### Scenario B: Deployed multiple changes, can't isolate the problem

**Action:** Full environment rollback from backup.

```bash
# Run restore drill to verify backup is good
./scripts/restore-drill.sh /var/backups/borg-repo /tmp/restore-drill

# If drill passes, restore
# Follow docs/backup-restore-runbook.md Procedure 3
```

### Scenario C: Database migration broke the schema

**Action:** Database rollback from pre-deploy backup.

```bash
# Stop the app
ssh deploy@10.10.1.2
sudo systemctl stop jol-backend jol-celery-worker jol-celery-beat

# Restore from backup
ssh deploy@10.10.1.7
ls -lt /var/backups/postgresql/*.dump | head -3
# Copy the most recent dump to DB host

# Restore on DB host
ssh deploy@10.10.1.3
sudo -u postgres psql -c "DROP DATABASE IF EXISTS jol_marketplace;"
sudo -u postgres psql -c "CREATE DATABASE jol_marketplace ENCODING 'UTF8';"
sudo -u postgres pg_restore -d jol_marketplace /tmp/LATEST_DUMP.dump

# Restart app
ssh deploy@10.10.1.2
sudo systemctl start jol-backend jol-celery-worker jol-celery-beat
```

### Scenario D: WAF rules blocking legitimate traffic

**Action:** Temporarily disable WAF, then fix rules.

```bash
# SSH to edge host
ssh deploy@10.10.1.1

# Comment out WAF rules in marketplace config
sudo sed -i 's/include \/etc\/nginx\/conf.d\/waf_rules.conf;/# WAF DISABLED FOR INCIDENT/' \
  /etc/nginx/sites-available/marketplace

# Reload nginx
sudo nginx -t && sudo systemctl reload nginx

# Verify traffic flows
curl -sk https://10.10.1.1/health

# Later: fix the WAF rules and re-enable
```

### Scenario E: TLS certificate expired or invalid

**Action:** Force certificate renewal.

```bash
# SSH to edge host
ssh deploy@10.10.1.1

# Force dehydrated renewal
sudo /usr/local/bin/dehydrated -c /etc/dehydrated/config --force

# Reload nginx
sudo systemctl reload nginx

# Verify certificate
echo | openssl s_client -connect 10.10.1.1:443 -servername staging.jolarca.org 2>/dev/null | openssl x509 -noout -dates
```

---

## Post-Rollback Verification

After any rollback, run the full smoke test suite:

```bash
./scripts/smoke-test-staging.sh
```

Expected output: all 18 checks pass.

If any check fails, escalate to the infrastructure lead.

---

## Communication Templates

### Internal notification (Slack/Teams)

```
🚨 INCIDENT: Deployment failure — [component] broken
Severity: P1/P2
Started: [timestamp]
Impact: [what's broken for users]
Action taken: [rollback procedure #N]
Status: [rolling back / rolled back / verifying]
ETA: [estimated time to resolution]
```

### Customer-facing (if service is down > 15min)

```
We're experiencing technical difficulties with [service].
Our team is investigating and working to restore service.
We'll provide updates as soon as possible.
```

---

## Post-Incident Review

Within 24 hours of resolution:

1. **Document the incident** — timeline, root cause, impact
2. **File a post-mortem** — what went wrong, what went right, action items
3. **Update the runbook** — if the procedure was unclear, fix it
4. **Schedule a review** — team meeting to discuss learnings

### Post-mortem template

```markdown
# Incident Post-Mortem: [Title]

## Summary
[1-2 sentence description]

## Timeline
- HH:MM — [event]
- HH:MM — [event]

## Impact
- Duration: [X minutes]
- Users affected: [number/percentage]
- Data loss: [yes/no]

## Root Cause
[What caused the incident]

## Resolution
[How it was fixed]

## Action Items
- [ ] [action item 1] — [owner] — [due date]
- [ ] [action item 2] — [owner] — [due date]

## Lessons Learned
[What went well, what could be improved]
```

---

## Emergency Contacts

| Role | Contact | When to call |
|------|---------|-------------|
| Infrastructure lead | [name/phone] | Any P1 incident |
| Backend lead | [name/phone] | API/database issues |
| Frontend lead | [name/phone] | UI/frontend issues |
| DPO | dpo@journeyoflife.org | Data breach suspected |
| Offsite provider | [provider contact] | Backup/restore issues |
