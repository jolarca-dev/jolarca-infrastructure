---
text: production-deployment-plan
version: 1.0.0
status: approved
---

# Production Deployment Plan

**Purpose:** Exact steps to cut over from staging to production on
Proxmox bare metal. Blue-green deployment with tested rollback.
**Prerequisite:** Production cutover gate passed (all items ✅).

---

## Architecture Overview

```
                    ┌──────────────────────────────────────┐
                    │           DNS: marketplace.jolarca.org│
                    └──────────────┬───────────────────────┘
                                   │
                    ┌──────────────▼───────────────────────┐
                    │     Edge VM (100) — nginx + WAF      │
                    │     TLS termination, rate limiting    │
                    └──────────────┬───────────────────────┘
                                   │ WireGuard mesh
              ┌────────────────────┼────────────────────┐
              │                    │                    │
    ┌─────────▼────────┐ ┌────────▼────────┐ ┌────────▼────────┐
    │ App VM (101)     │ │ DB VM (102)     │ │ Vault LXC (103) │
    │ Django + Next.js │ │ PostgreSQL 17   │ │ Secrets + PKI   │
    │ Celery workers   │ │ PostGIS+vector  │ │                 │
    └──────────────────┘ └─────────────────┘ └─────────────────┘
              │                    │
    ┌─────────▼────────┐ ┌────────▼────────┐
    │ MinIO VM (200)   │ │ Backup VM (202) │
    │ S3-compatible    │ │ BorgBackup      │
    └──────────────────┘ └─────────────────┘
```

---

## Phase 0: Pre-Deployment (Day -7)

### 0.1 Verify cutover gate
```bash
# Run automated pre-gate checks
./scripts/pre-gate-check.sh

# Review gate document
cat docs/production-cutover-gate.md
# All Critical + High items must be ✅ or risk-accepted
```

### 0.2 Provision production infrastructure
```bash
# Create production VMs/LXCs from Terraform
cd terraform/environments/production
terraform init
terraform plan  # Review carefully
terraform apply

# Run hardening + WireGuard playbooks
cd /opt/jolarca/repos/jolarca-infrastructure
ansible-playbook ansible/playbooks/00-hardening.yml -i ansible/inventories/production/hosts.yml
ansible-playbook ansible/playbooks/10-wireguard.yml -i ansible/inventories/production/hosts.yml
```

### 0.3 Deploy data tier
```bash
ansible-playbook ansible/playbooks/30-vault.yml -i ansible/inventories/production/hosts.yml
ansible-playbook ansible/playbooks/40-postgresql.yml -i ansible/inventories/production/hosts.yml
ansible-playbook ansible/playbooks/50-minio.yml -i ansible/inventories/production/hosts.yml
```

### 0.4 Deploy backup + monitoring
```bash
ansible-playbook ansible/playbooks/80-backup.yml -i ansible/inventories/production/hosts.yml
ansible-playbook ansible/playbooks/95-monitoring.yml -i ansible/inventories/production/hosts.yml
```

### 0.5 Soak test (7 days minimum)
- Run staging workloads against production infrastructure
- Monitor for 7 days with no P1 incidents
- Verify all Prometheus targets are UP
- Run restore drill on production-like data

---

## Phase 1: Deploy Application (Day 0)

### 1.1 Deploy to production (blue — standby)
```bash
# Deploy app to production (port 8001 — not yet serving traffic)
ansible-playbook ansible/playbooks/65-app.yml \
  -i ansible/inventories/production/hosts.yml \
  --extra-vars "app_port=8001 app_environment=production"

# Run database migrations
ssh deploy@10.10.1.2 "cd /opt/jolarca/backend && python manage.py migrate --noinput"

# Collect static files
ssh deploy@10.10.1.2 "cd /opt/jolarca/backend && python manage.py collectstatic --noinput"

# Verify health on standby port
curl -s http://10.10.1.2:8001/api/v1/health/ | python3 -m json.tool
```

### 1.2 Deploy nginx with blue-green routing
```bash
# Deploy nginx pointing to STANDBY (port 8001)
ansible-playbook ansible/playbooks/70-nginx-edge.yml \
  -i ansible/inventories/production/hosts.yml \
  --extra-vars "backend_upstream=http://10.10.1.2:8001"

# Apply hardening
ansible-playbook ansible/playbooks/90-nginx-hardening.yml \
  -i ansible/inventories/production/hosts.yml

# Verify via nginx
curl -sk https://10.10.1.1/health | python3 -m json.tool
```

### 1.3 Run smoke tests against production
```bash
./scripts/smoke-test-staging.sh  # Adapted for production IPs
```

---

## Phase 2: DNS Cutover (Day 0, +1h)

### 2.1 Lower DNS TTL
```bash
# 24 hours before cutover, lower TTL to 60 seconds
# In DNS provider console:
# marketplace.jolarca.org → A → <production-edge-ip> → TTL 60
```

### 2.2 Switch DNS
```bash
# Point production DNS to the new edge IP
# In DNS provider console:
# marketplace.jolarca.org → A → <production-edge-ip>

# Wait for propagation (typically 5-15 minutes with TTL 60)
dig +short marketplace.jolarca.org @8.8.8.8
dig +short marketplace.jolarca.org @1.1.1.1
```

### 2.3 Verify production traffic
```bash
# Check that real users are reaching the new production
curl -sk https://marketplace.jolarca.org/health | python3 -m json.tool
curl -sk https://marketplace.jolarca.org/api/v1/health/ | python3 -m json.tool

# Monitor Grafana dashboard
# http://10.10.1.6:3000/d/jolarca-overview
```

---

## Phase 3: Post-Cutover (Day 0, +2h)

### 3.1 Enable Stripe live mode
```bash
# Update Stripe keys from test to live
# In Vault: update STRIPE_SECRET_KEY and STRIPE_WEBHOOK_SECRET
# Restart backend
ssh deploy@10.10.1.2 "sudo systemctl restart jol-backend"

# Verify Stripe webhooks are flowing
# Check Stripe Dashboard → Developers → Webhooks
```

### 3.2 Enable Let's Encrypt
```bash
# Switch from snakeoil to Let's Encrypt
ssh deploy@10.10.1.1
sudo /usr/local/bin/dehydrated -c /etc/dehydrated/config --force
sudo systemctl reload nginx

# Verify certificate
echo | openssl s_client -connect marketplace.jolarca.org:443 \
  -servername marketplace.jolarca.org 2>/dev/null \
  | openssl x509 -noout -issuer -dates
```

### 3.3 Monitor for 24 hours
- Watch Grafana dashboard continuously
- Check Alertmanager for any firing alerts
- Review nginx access logs for anomalies
- Monitor Stripe webhook delivery rate

---

## Phase 4: Decommission Staging (Day +7)

### 4.1 Final verification
```bash
# Run full smoke test against production
./scripts/smoke-test-staging.sh

# Run restore drill on production
./scripts/restore-drill.sh /var/backups/borg-repo /tmp/restore-drill

# Verify all monitoring targets UP
curl -s http://10.10.1.6:9090/api/v1/targets | python3 -m json.tool
```

### 4.2 Staging remains available
- Do NOT decommission staging — it serves as:
  - Development/testing environment
  - Disaster recovery fallback
  - Rollback target if production needs to be restored

---

## Rollback Procedure

If anything goes wrong during cutover:

### Immediate rollback (DNS)
```bash
# Point DNS back to previous IP (or staging)
# In DNS provider console:
# marketplace.jolarca.org → A → <previous-ip>
# TTL was already lowered to 60s, so propagation is fast
```

### Application rollback
```bash
# Switch nginx back to previous backend
ansible-playbook ansible/playbooks/70-nginx-edge.yml \
  -i ansible/inventories/production/hosts.yml \
  --extra-vars "backend_upstream=http://10.10.1.2:8000"

# Or roll back the code
ssh deploy@10.10.1.2 "cd /opt/jolarca/backend && git checkout HEAD~1"
ssh deploy@10.10.1.2 "docker compose -f /opt/jolarca/docker-compose.backend.yml up -d --build"
```

### Database rollback
```bash
# Follow docs/backup-restore-runbook.md Procedure 2
# Restore from pre-deploy backup
```

### Full environment rollback
```bash
# Follow docs/backup-restore-runbook.md Procedure 3
# Restore entire environment from BorgBackup
```

---

## Timeline Summary

| Day | Activity | Duration | Risk |
|-----|----------|----------|------|
| D-7 | Provision production infra | 4h | Low |
| D-7 to D-1 | Soak test (7 days) | 7 days | Low |
| D-1 | Lower DNS TTL | 5min | Low |
| D0 00:00 | Deploy app (standby) | 30min | Medium |
| D0 01:00 | DNS cutover | 15min | **High** |
| D0 01:30 | Enable Stripe live | 15min | **High** |
| D0 02:00 | Enable Let's Encrypt | 10min | Low |
| D0 02:00-26:00 | Monitor (24h) | 24h | Medium |
| D+7 | Final verification | 2h | Low |

**Total cutover window:** ~2 hours (DNS switch to Stripe live)
**Rollback time:** < 15 minutes (DNS TTL 60s)
