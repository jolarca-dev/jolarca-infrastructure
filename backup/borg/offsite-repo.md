# Offsite Borg repository specification

**Status: reserved — lands with the backup workstream (`ansible/playbooks/50-backup.yml`).**

## Requirements (non-negotiable)

1. **Separate provider and region** from primary hosting — a compromise of
   the primary provider must not take the backup plane with it.
2. **Encrypted at rest by Borg itself** (repokey-blake2): the offsite
   provider never sees plaintext. Passphrase custody per
   `../../security/key-custody.md` (dual control, distinct from the
   ansible-vault passwords).
3. **Append-only mode** where the provider supports it: a compromised
   client credential may add archives, not delete or rewrite them.
4. **EU residency** for any archive containing personal data
   (GDPR Art. 44 — no transfer outside adequacy without SCCs + DPIA).
5. **Independent restore path**: offsite restore must work without access
   to the primary datacenter at all.

## Config targets

- `borgmatic.staging.yml` / `borgmatic.production.yml` land here with
  schedules, retention (daily ×7, weekly ×4, monthly ×12), and excludes.
- Offsite copy runs after local prune/verify, never instead of it.

## Drill linkage

Offsite restore is exercised in the quarterly drill (`../restore-drill.md`).
An offsite target that has never been restored from is not a backup.
