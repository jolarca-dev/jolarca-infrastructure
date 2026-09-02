# ansible/ — the 90% bare-metal plane

Infrastructure-as-code for all Proxmox VMs and LXCs. Tested locally with
Molecule (Docker), deployed via Ansible playbooks.

## Layout

```text
ansible.cfg                # Vault integration, SSH pipelining, fact caching
requirements.yml           # PINNED collections with versions
.ansible-lint              # Lint configuration (production profile)
.yamllint                  # YAML lint configuration
inventories/
  staging/hosts.yml        # Fill-in-the-blanks for Proxmox IPs
  production/              # Production inventory (separate vault)
playbooks/                 # Numbered: 00-hardening through 60-backup
roles/                     # One role per concern, each with molecule/ tests
  hardening/               # CIS baseline (sshd, nftables, fail2ban, auditd)
  wireguard/               # Mesh VPN (the ONLY bridge between planes)
  postgresql/              # PG 17 + PostGIS 3.5 + pgvector + TLS
  vault/                   # HashiCorp Vault (raft, TLS, audit)
  minio/                   # S3-compatible object storage (EU residency)
  nginx/                   # Reverse proxy, security headers, rate limiting
  backup/                  # BorgBackup with encryption + retention
group_vars/all/            # Global variables + Vault secret paths
vault/{staging,production}/ # ansible-vault encrypted secrets (dual control)
```

## Bootstrap order

```
00-hardening → 10-wireguard → 20-postgresql → 30-vault → 40-minio →
50-nginx → 60-backup
```

Skipping steps is a change-request exception, not a habit.

## Vault password custody (dual control)

- Staging and production use **different** vault passwords.
- Production password is held by exactly two operators; neither alone can
  decrypt. Custody changes are recorded in `../security/key-custody.md`.
- Password files live OUTSIDE this repo (`.vault-pass-*` is gitignored).

## Local testing

See [`../docs/ansible-local-testing.md`](../docs/ansible-local-testing.md)
for full instructions. Quick start:

```bash
# Test a single role
cd ansible/roles/hardening && molecule test

# Lint all playbooks
cd ansible && ansible-lint
```

## CI

The CI workflow (`.github/workflows/ansible.yml`) runs on every PR:

1. **ansible-lint** — static analysis
2. **Syntax check** — validates against staging inventory
3. **Molecule test** — Docker-based convergence + verification per role

## Ansible Vault vs HashiCorp Vault

| Use case | Tool | Rationale |
|----------|------|-----------|
| Playbook secrets (SSH keys, DB passwords during provisioning) | ansible-vault | Encrypted at rest in repo; dual-control password |
| Runtime application secrets (Django, Stripe) | HashiCorp Vault | Dynamic secrets, audit log, auto-rotation |
| CI/CD secrets | GitHub Secrets | Scoped to repo; never in code |

See `group_vars/all/vault-paths.yml` for the HashiCorp Vault secret path
registry.
