# ansible/ — the 90% bare-metal plane — RESERVED

Workstream **pending**. The directory skeleton is committed so the CI gate
(`.github/workflows/ansible.yml`) self-activates the moment content lands.

## Planned layout (from the Moat blueprint)

```text
ansible.cfg                # vault integration, fact caching, SSH pipelining
requirements.yml           # PINNED collections with versions
inventories/{staging,production}/hosts.yml + group_vars/
playbooks/                 # numbered: 00-hardening … 90-disaster-recovery, 99-verify
roles/*/                   # one role per concern, each with molecule/ tests
vault/{staging,production}/secrets.yml   # ansible-vault encrypted, per-env passwords
```

## Vault password custody (dual control)

- Staging and production use **different** vault passwords.
- Production password is held by exactly two operators; neither alone can
  decrypt. Custody changes are recorded in `../security/key-custody.md`.
- Password files live OUTSIDE this repo (`.vault-pass-*` is gitignored).

## Bootstrap order (planned)

00-hardening → 10-wireguard → 20-postgresql → 30-vault → 40-minio →
50-backup → 60-nginx-edge → 70-monitoring → 90-disaster-recovery →
99-verify. Skipping steps is a change-request exception, not a habit.

Do not commit playbooks until the workstream change request is approved.
