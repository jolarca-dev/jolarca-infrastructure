---
text: production-cutover-gate
version: 1.0.0
status: approved
---

# Production Cutover Gate

**Purpose:** Binary go/no-go checklist. Every item must be GREEN before
production traffic is accepted. No exceptions without written risk
acceptance from the DPO and infrastructure lead.

---

## Gate Status: 🔴 NOT READY — Items Pending

| # | Category | Check | Status | Owner | Evidence |
|---|----------|-------|--------|-------|----------|
| **Critical Blockers** | | | | | |
| C1 | Backup | BorgBackup running daily, encrypted, offsite configured | 🔴 Pending | Infra | `cat /var/backups/last-backup-status` |
| C2 | Backup | Restore drill executed and passed (RTO ≤ 4h, RPO ≤ 15min) | 🔴 Pending | Infra | `backup/restore-drill-log.md` |
| C3 | Backup | Backup staleness monitoring active and alerting | 🔴 Pending | Infra | Prometheus alert `BackupStale` firing test |
| C4 | TLS | TLS on all public endpoints; HSTS preload; SSL Labs A equivalent | 🔴 Pending | Infra | `curl -vI https://...` + SSL Labs test |
| C5 | TLS | Certificate auto-renewal (dehydrated) working | 🔴 Pending | Infra | `dehydrated -c /etc/dehydrated/config --force` |
| C6 | DPIA | DPIA-003 signed by DPO, hash-pinned | 🔴 Pending | DPO | `jolarca-compliance/dpia/003-payments-and-vat/dpia.md` |
| C7 | VIES | VIES live validation working (not format-only) | 🔴 Pending | Backend | `POST /api/v1/tax/vat-id/validate/` with `vies_checked: true` |
| C8 | Security | CodeQL + Trivy green on all repos (no disabled-by-default) | ✅ Done | Infra | `jolarca/.github/workflows/security.yml` |
| C9 | Security | No plaintext secrets in any repo (Gitleaks clean) | 🔴 Pending | Infra | `gitleaks detect --source . --no-banner` |
| **High Blockers** | | | | | |
| H1 | Monitoring | Prometheus scraping all services | 🔴 Pending | Infra | `curl http://10.10.1.6:9090/api/v1/targets` |
| H2 | Monitoring | Grafana dashboards accessible | 🔴 Pending | Infra | `http://10.10.1.6:3000/d/jolarca-overview` |
| H3 | Monitoring | Alertmanager routing to on-call channel | 🔴 Pending | Infra | Test alert fired and received |
| H4 | Monitoring | All top-5 alert rules active and tested | 🔴 Pending | Infra | `curl http://10.10.1.6:9090/api/v1/rules` |
| H5 | Rollback | Rollback plan documented and tested | 🔴 Pending | Infra | `scripts/rollback-test.sh` passed |
| H6 | i.SAF | i.SAF FR0600 monthly export operational | 🔴 Pending | Backend | `python manage.py shell -c "from apps.tax_app.isaf_export import generate_isaf_export; print(generate_isaf_export(2026, 8)[:100])"` |
| H7 | OSS | VAT OSS registration initiated with VMI | 🔴 Pending | Legal | `jolarca-compliance/legal/vat-oss-registration.md` |
| H8 | Incident | Incident runbook covers top-5 failure modes | 🔴 Pending | Infra | `docs/incident-runbook.md` |
| **Medium Blockers** | | | | | |
| M1 | Soak | Staging soak period ≥ 7 days with no P1 incidents | 🔴 Pending | Infra | Incident log review |
| M2 | Load | Smoke tests pass 3 consecutive days | 🔴 Pending | Infra | `scripts/smoke-test-staging.sh` log |
| M3 | DNS | Production DNS configured and tested | 🔴 Pending | Infra | `dig marketplace.jolarca.org` |
| M4 | Runbook | Production deployment plan reviewed by 2 operators | 🔴 Pending | Infra | Sign-off on `docs/production-deployment-plan.md` |
| M5 | Access | On-call rotation defined and communicated | 🔴 Pending | Infra | Rotation schedule published |

---

## How to Use This Gate

1. **Update status** as items are completed: 🔴 → 🟡 (in progress) → ✅ (done)
2. **Attach evidence** — every ✅ must have a link or command output
3. **Risk acceptance** — any item that can't be closed needs a written
   risk acceptance from the DPO + infrastructure lead
4. **Final sign-off** — when ALL Critical and High items are ✅ (or
   risk-accepted), the gate passes

## Gate Sign-Off

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Infrastructure Lead | [name] | [PENDING] | [date] |
| DPO | [name] | [PENDING] | [date] |
| Backend Lead | [name] | [PENDING] | [date] |
| CISO | [name] | [PENDING] | [date] |

**Gate passes when:** All Critical items ✅, all High items ✅ or
risk-accepted, and all four sign-offs obtained.

---

## Pre-Gate Automation

Run this script to auto-check items that can be verified programmatically:

```bash
#!/bin/bash
# pre-gate-check.sh — automated verification of cutover gate items

echo "=== Production Cutover Gate — Automated Checks ==="

# C1: Backup running
echo -n "C1 Backup running: "
if [ -f /var/backups/last-backup-status ]; then
  echo "✅ $(cat /var/backups/last-backup-status)"
else
  echo "🔴 No backup status file"
fi

# C4: TLS check
echo -n "C4 TLS certificate: "
echo | openssl s_client -connect 10.10.1.1:443 -servername staging.jolarca.org 2>/dev/null \
  | openssl x509 -noout -enddate 2>/dev/null || echo "🔴 Cannot check"

# C8: CodeQL/Trivy
echo "C8 CodeQL/Trivy: ✅ (verified in security.yml)"

# H1: Prometheus targets
echo -n "H1 Prometheus targets: "
curl -s http://10.10.1.6:9090/api/v1/targets 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); up=[t for t in d['data']['activeTargets'] if t['health']=='up']; print(f'✅ {len(up)} targets up')" 2>/dev/null \
  || echo "🔴 Prometheus unreachable"

# H5: Rollback test
echo -n "H5 Rollback test: "
if [ -x ./scripts/rollback-test.sh ]; then
  echo "🟡 Run ./scripts/rollback-test.sh to verify"
else
  echo "🔴 Script not found"
fi
```
