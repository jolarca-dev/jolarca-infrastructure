# ADR-0003: Encrypted remote state migration (local → GCS)

- **Status:** Proposed (resolves the "ADR pending" note previously carried
  in `terraform/environments/production/main.tf`)
- **Date:** 2026-08-14
- **Deciders:** pending two-person sign-off

## Context

Current state lives on operator machines (`backend "local"`). Acceptable
for bootstrap of the GitHub-org baseline; unacceptable once real cloud
resources exist. Migration is a **Crit-class change** (CONTRIBUTING.md).

## Decision (proposed)

Migrate each environment to its dedicated GCS backend
(`terraform/backends/*.backend.hcl`) following the ordered procedure in
`terraform/README.md` ("State bootstrap procedure"): state-bucket module
first, staging migrated and soaked, then production. Local state copies
are securely deleted after verified migration.

## Open questions (must close before acceptance)

- [ ] Bucket naming + project placement approved
- [ ] CMEK key rings created and custodians named (`security/key-custody.md`)
- [ ] CI service accounts scoped per environment (no shared SA)
- [ ] Backup layer (`backup/terraform-state/`) live before migration
- [ ] Change window + rollback (restore local backend) rehearsed

## Consequences

- (+) State gains versioning, CMEK, audit logging, independent backup.
- (−) All operators lose local state convenience — by design.

## Compliance mapping

SOC 2 CC6.6, ISO 27001 A.8.24; migration record itself is CC8.1 evidence.
