# Restore drill runbook & log

**Targets: RTO ≤ 4h, RPO ≤ 15min.** Cadence: quarterly (ISO 27001 A.5.29 /
A.5.30 business continuity testing; SOC 2 A1.3).

## Drill scope (repeat each quarter)

1. **State restore**: recover production Terraform state from the versioned
   bucket into a scratch bucket; verify plan against live resources
   (`backup/terraform-state/README.md`).
2. **Data restore**: restore PostgreSQL PITR snapshot of a test database to
   a point-in-time ≤ 15min before the drill marker (verifies RPO).
3. **Offsite restore**: pull one borg archive from the offsite provider and
   extract a canary file (verifies the offsite path works cold).
4. **Rebuild path**: rebuild one hardened node from zero using
   `ansible/playbooks/90-disaster-recovery.yml` (when the ansible
   workstream has landed).

## Pass criteria

- All four steps completed within 4h wall clock (RTO).
- PITR restore landed within 15min of the marker (RPO).
- Every anomaly observed during the drill filed as an issue.

## Drill log

| Date       | Lead | Scope executed | RTO result | RPO result | Findings/issues |
|------------|------|----------------|------------|------------|-----------------|
| _pending_  | —    | —              | —          | —          | —               |

Entries are append-only evidence. Never edit past rows; correct with a
new row referencing the original.
