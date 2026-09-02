# Operations Runbook Index

Single entry point for all operational procedures. A second operator
should be able to handle any incident using only the documents linked here.

---

## Deployment

| Procedure | Document | When to use |
|-----------|----------|-------------|
| Staging deployment | `docs/staging-deployment-runbook.md` | First deploy or rebuild of staging |
| Production deployment | `docs/production-deployment-plan.md` | Cut over from staging to production |
| Rollback | `docs/rollback-plan.md` | Any deployment that went wrong |
| Blue-green / canary | `docs/deployment-strategy.md` | Future production rollout strategy |

## Incident Response

| Procedure | Document | When to use |
|-----------|----------|-------------|
| Top-5 failure modes | `docs/incident-runbook.md` | DB down, webhook failure, Vault sealed, backup stale, WireGuard failure |
| Deployment failure | `docs/incident-response-deployment.md` | Deployment-specific incidents |
| Security incident | `docs/threat-model.md` | Suspected breach, data leak, attack |

## Backup & Recovery

| Procedure | Document | When to use |
|-----------|----------|-------------|
| Backup & restore | `docs/backup-restore-runbook.md` | Restore from backup, verify backups |
| Restore drill | `backup/restore-drill-log.md` | Quarterly restore drill |
| Terraform state recovery | `backup/terraform-state/README.md` | Terraform state corruption |

## Monitoring & Alerting

| Procedure | Document | When to use |
|-----------|----------|-------------|
| Grafana dashboards | `http://10.10.1.6:3000/d/jolarca-overview` | Day-to-day monitoring |
| Alert rules | `monitoring/alerts/rules.yml` | Understanding what triggers alerts |
| Alertmanager routes | `monitoring/alertmanager/alertmanager.yml` | Understanding alert routing |

## Security

| Procedure | Document | When to use |
|-----------|----------|-------------|
| Vault operations | `docs/vault-tls-chain.md` | Vault TLS, CA bootstrap |
| Key custody | `security/key-custody.md` | Unseal share distribution, rotation |
| Access review | `security/access-review.md` | Quarterly access review |
| Secret sync | `docs/secrets-flow.md` | HV → AV bridge, secret injection |

## Infrastructure

| Procedure | Document | When to use |
|-----------|----------|-------------|
| Terraform Proxmox | `docs/terraform-proxmox.md` | VM/LXC provisioning |
| Ansible testing | `docs/ansible-local-testing.md` | Molecule testing |
| Proxmox user | `docs/proxmox-terraform-user.md` | Terraform API token management |
| Network isolation | `security/isolation-model.md` | WireGuard mesh, service binding |

---

## Quick Reference

### Hosts (WireGuard IPs)

| Host | IP | Role |
|------|-----|------|
| edge | 10.10.1.1 | nginx, TLS termination, WAF |
| app | 10.10.1.2 | Django, Celery, Redis |
| db | 10.10.1.3 | PostgreSQL 17 |
| vault | 10.10.1.4 | HashiCorp Vault |
| minio | 10.10.1.5 | MinIO object storage |
| monitor | 10.10.1.6 | Prometheus, Grafana, Alertmanager |
| backup | 10.10.1.7 | BorgBackup |

### Key Commands

```bash
# Smoke test
./scripts/smoke-test-staging.sh

# Restore drill
./scripts/restore-drill.sh

# Rollback test
./scripts/rollback-test.sh

# Backup status
ssh deploy@10.10.1.7 "cat /var/backups/last-backup-status"

# Vault status
curl -sk https://10.10.1.4:8200/v1/sys/health | python3 -m json.tool

# Monitoring targets
curl -s http://10.10.1.6:9090/api/v1/targets | python3 -m json.tool
```
